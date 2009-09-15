#!/usr/bin/ruby -w
#
# Author: Soo Hwan Park (suwanny@gmail.com)
# 

require "yaml"
require "Configuration"
require "logger"
require 'net/http'
require 'uri'
require 'openssl'
require 'socket'
require 'timeout'

class RemoteFunctions
  attr_reader :logger, :rootDir, :config, :ips
  #attr_writer   

  def initialize()
    #log = Logger.new(rootDir + "/logs/appbench.log")
    #@logger = Logger.new(STDOUT)
    @rootDir = Dir.pwd[0, Dir.pwd.rindex("/")]
    @logger = Logger.new(@rootDir + "/logs/appbench.log", "daily")
    @logger.datetime_format = "%H:%M:%S"
    @logger.level = Logger::DEBUG
    @logger.info "RemoteFunctions Initialized"
    @config = YAML.load_file(@rootDir + "/bin/config.yaml")
    @ips = YAML.load_file("ips.yaml")

    # key information 
    @pri_key_loc = @rootDir + "/key/appscale"
    @pub_key = `cat #{@rootDir + "/key/appscale.pub"}`
    pub_key_info = @pub_key.split(' ')
    @key_id = pub_key_info[2] 
  end

  def has_key(user_server)
    user, server = user_server.split('@')
    output = `ssh -i #{@pri_key_loc} #{user}@#{server} grep #{@key_id} ~#{user}/.ssh/authorized_keys`
    output.rindex(@key_id) if output.class == String
  end

  def install_key(user_server)
    user, server = user_server.split('@')
    output = `ssh #{user_server} "echo '#{@pub_key}' >> ~#{user}/.ssh/authorized_keys"`
    @logger.debug output
  end

  def exec(login, command) 
    output = `ssh -i #{@pri_key_loc} #{login} "#{command}"`
  end

  def system(login, command, fork = true)
    if fork 
      cmd = "ssh -i #{@pri_key_loc} #{login} \"#{command}\" &"
    else
      cmd = "ssh -i #{@pri_key_loc} #{login} \"#{command}\""
    end 
    Kernel.system cmd
  end

  def is_port_open?(ip, port)
    begin
      Timeout::timeout(1) do
        begin
          sock = TCPSocket.new(ip, port)
          sock.close
          return true
        rescue Exception
          return false
        end
      end
    rescue Timeout::Error
    end
    return false
  end

  def sleep_until_port_is_open(ip, port)
    loop {
      return if is_port_open?(ip, port)
      sleep(1)
    }
  end

  def sleep_until_port_is_closed(ip, port)
    loop {
      return if !is_port_open?(ip, port)
      sleep(1)
    }
  end

  def readURI?(web_uri)
    url = URI.parse(web_uri)
    begin
      res = Net::HTTP.start(url.host, url.port) {|http| http.get('/'); }
      return true
      #res.code
    rescue
      return false
    end
  end

  def pollAppEngine(appengine, maxSec = 20*60)
    web = "http://" + appengine + ":8080"
    while maxSec > 0 
      return true if readURI?(web)
      sleep(1)
      maxSec -= 1
    end
    return false
  end 

  def spawnApp(app, datastore)
    # shutdown first 
    bin = "~/appscale-tools/bin"
    cmd = bin + "/appscale-terminate-instances.rb -ips #{bin}/ips.yaml"
    @logger.debug "shutdown application"
    @logger.debug exec(@config.appscale, cmd) 
    @logger.debug "shutdown completed"
   
    #cmd = bin + "/appscale-run-instances.rb -v -ips #{bin}/ips.yaml"
    cmd = bin + "/appscale-run-instances.rb -ips #{bin}/ips.yaml"
    cmd += " -file #{bin}/../sample_apps/#{app}.tar.gz"
    #cmd += " -table #{datastore} -v"
    cmd += " -table #{datastore} "
    @logger.debug "spawn application: #{app}"
    system(@config.appscale, cmd) 
    @logger.debug "spawning application completed"
  end

  def rebootMachines(machines)
    cmd = "reboot"
    machines.each { |machine| system("root@#{machine}", cmd); } 
    machines.each { |machine| sleep_until_port_is_closed(machine, 80); }
    machines.each { |machine| sleep_until_port_is_open(machine, 80); }
  end

  def startConsole()
    console = @config.console
    user, server = console.split('@')
    cmd = "~/AppBenchmark/bin/console.sh restart"
    @logger.info "start console: #{console}"
    system(console, cmd)
    sleep 2
    sleep_until_port_is_open(server, 6372)
    @logger.info "start console completed"     
  end

  def stopConsole()
    console = @config.console
    cmd = "~/AppBenchmark/bin/console.sh stop"
    @logger.info "stop console: #{console}"
    system(console, cmd)
  end

  def startAgents(app)
    agents = @config.agents
    stop = "~/AppBenchmark/bin/agent.sh stop"
    start = "~/AppBenchmark/bin/agent.sh start #{app}"
    agents.each { |agent| 
      @logger.info "start agent: #{agent}" 
      #system(agent, stop)
      system(agent, start)
    }

    # Waiting for "CONNECTED"
    loop {
      break if getConsoleStatus == "CONNECTED"
      sleep 1
    }
  end

  def sendDeleteAllRecord(datastore)
    master =  @ips[:controller] 
    slaves = @ips[:servers]
    cmd = "python /root/appscale/AppDB/delete_all_record.py #{datastore}" 
    if datastore == "mysql"
      slaves.each { |slave| exec("root@" + slave, cmd); }
    else
      exec("root@" + master, cmd) 
    end
  end

  def sendStartToAgents()
    # should delete old data at datastore 
    user, server = @config.console.split('@')
    status = `#{@rootDir}/lib/remoteconsole/remote -h #{server}:7070 start 1 1`
    loop {
      break if getConsoleStatus == "WORKING"
      sleep 1
    }
  end
  
  def sendStopToAgents()
    user, server = @config.console.split('@')
    status = `#{@rootDir}/lib/remoteconsole/remote -h #{server}:7070 stop 1 1`

    agents = @config.agents
    for i in 1..agents.length
      cmd = "~/AppBenchmark/bin/agent.sh stop"
      exec(agents[i-1], cmd)
    end
    loop {
      break if getConsoleStatus == "INIT"
      sleep 1
    }
  end

  def getConsoleStatus(num_agent = 3)
    user, server = @config.console.split('@')
    status = `#{@rootDir}/lib/remoteconsole/remote -h #{server}:7070 get_status 1 1`
    #@logger.debug status

    return "INIT" if status.length == 0
    agents = status.split(',')
    return "INIT" if agents.length < num_agent
    agents.each { |agent| 
      agent_info = agent.split()
      return "WORKING" if agent.index("Worker")
    }
    return "CONNECTED" if status.index("Connected")
  end

  # ask the repository to make data folders 
  def initDataDirectory(test_id)
    cmd = "~/AppRepository/makeDataDir.sh #{test_id}"
    exec(@config.repository, cmd) 
  end 

  def makeDescription(test_id, msg)
    html = <<END_HTML
<html><head><title>#{test_id}</title></head>
<body><font face=Georgia size=3>#{msg}</font></body></html>
END_HTML
    cmd = "echo '#{html}' > /var/www/#{test_id}/report.html"
    exec(@config.repository, cmd)
  end

  def sendLogFiles(test_id, application)
    agents = @config.agents
    for i in 1..agents.length
      cmd = "~/AppBenchmark/bin/sendlog.sh #{@config.repository} #{test_id} #{i} #{application}"
      exec(agents[i-1], cmd) 
    end 
  end 

  def insertData2DB(test_id, sample_index)
    agents = @config.agents
    for i in 1..agents.length
      cmd = "~/AppBenchmark/bin/insert_datalog.py #{test_id} #{i} #{sample_index}"
      exec(agents[i-1], cmd)
    end
  end 

  def processLogs(test_id, datastore, num_agent, num_test)
    cmd = "~/AppRepository/makegraph.sh #{test_id} #{datastore} #{num_agent} #{num_test}"
    exec(@config.repository, cmd)
  end 

  def sendNotification(to, subject, message)
    require 'net/smtp'
    msg = <<END_OF_MESSAGE
From: AppScaleNotification <appscale@cs.ucsb.edu>
To: #{to}
MIME-Version: 1.0
Content-type: text/html
Subject: [AppBench] #{subject}

<font face=Georgia size=3>#{message}</font>
END_OF_MESSAGE
    Net::SMTP.start('localhost') do |smtp| 
    #Net::SMTP.start('mail.twolves.cs.ucsb.edu') do |smtp| 
      smtp.send_message msg, "appscale@cs.ucsb.edu", to 
    end 
  end

end

  
