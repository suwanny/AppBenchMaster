#!/usr/bin/ruby

require "RemoteFunctions"

remote = RemoteFunctions.new 
log = remote.logger

log.debug remote.rootDir
config = remote.config 
ips = YAML.load_file("ips.yaml")
log.debug ips[:controller]
log.debug ips[:servers]

#log.debug "appscale: #{config.appscale}"
#log.debug "console: #{config.console}"
#config.agents.each { |agent| log.debug "agent: #{agent}"; }
#log.debug "repository: #{config.repository}"
#remote.install_key("spark2007@scala.cs.ucsb.edu") unless remote.has_key("spark2007@scala.cs.ucsb.edu")
#puts remote.has_key("root@128.111.55.227")

machines = Array.new
machines.push config.appscale
machines.push config.repository
config.agents.each { |agent| machines.push agent; }
#machines.each { |machine| 
#  log.debug "install key: #{machine}" 
#  remote.install_key(machine) unless remote.has_key(machine)
#  log.debug remote.exec(machine, "hostname")
#}

application = "guestbook"
datastore = "cassandra"

=begin
#remote.spawnApp(application, datastore)
# check here .. 
appengines = ips[:servers]
appengines.each { |appengine|
  log.debug "waiting until the appengine is running :#{appengine}"
  unless remote.pollAppEngine(appengine)
    log.error "poll App Engine Timeout: #{appengine}"
    Process.exit
  end
}
log.info "Application: (#{application}, #{datastore}) is running successfully"

remote.startConsole
remote.sleep_until_port_is_open("bulls.cs.ucsb.edu", 7070)
log.info "Start Console is completed"

# running sendStart&Polling .. 
log.info "get_status of the console"
log.debug remote.getConsoleStatus 

log.info remote.startAgents(application)
sleep 5

5.times { |i| 
  log.info remote.sendDeleteAllRecord(datastore)
  log.info remote.sendStartToAgents
  loop { 
    sleep 5
    break if remote.getConsoleStatus == "CONNECTED"
    log.debug remote.getConsoleStatus
  }
  log.info "test is finished"
  log.debug remote.getConsoleStatus 
} 

#test_time=`date +%Y%m%d%H`
#test_id = test_time.chomp + "_" + application + "_" + datastore
test_id = `date +%Y%m%d%H`.chomp + "_" + application + "_" + datastore
puts test_id
remote.initDataDirectory(test_id)
remote.sendLogFiles(test_id, application)
remote.processLogs(test_id, datastore, 3, 5)
=end

log.info "************************** master script is finished"





