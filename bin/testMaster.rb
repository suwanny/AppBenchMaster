#!/usr/bin/ruby
#
# TestMaster.rb
# Author: Soo Hwan Park (suwanny@gmail.com)
#

require "RemoteFunctions"
remote = RemoteFunctions.new 
$log = remote.logger
$config = remote.config 
$ips = remote.ips
$events = [] 
$start_time = Time.now
$before_event = $start_time

def installKeys(remote)
  machines = Array.new
  machines.push $config.appscale
  machines.push $config.repository
  $config.agents.each { |agent| machines.push agent; }
  machines.each { |machine| 
    log.debug "install key: #{machine}" 
    remote.install_key(machine) unless remote.has_key(machine)
  }
end

def write_event(msg)
  current = Time.now
  event = "%.6f,%.6f\t: #{msg}" % [current - $start_time, current - $before_event] 
  $before_event = current 
  $events.push event
  $log.info event
end
  
def sendNotification(remote, app, db, test_id)
  msg = "<h1>#{app} with #{db}</h1>\n"
  $events.each { |event| 
    msg += event + "<br>\n"
  } 
  remote.sendNotification("suwanny@gmail.com", "Test Report: #{app} with #{db}", msg)
  remote.makeDescription(test_id, msg)
  $events = []
end 

def rebootAppScale(remote)
  appengines = Array.new
  appengines.push $ips[:controller]
  $ips[:servers].each { |server| appengines.push server; }

  start = Time.now
  remote.rebootMachines(appengines)
  elapsed = Time.now - start
  puts "Reboot takes %.6f" % elapsed
end 

def doTest(remote, application, datastore)
  $events = Array.new
  $start_time = $before_event = Time.now
  log = $log

  # 1. Spawn Application 
  log.info "Spawn Application" 
  remote.spawnApp(application, datastore) 
  appengines = remote.ips[:servers]

  # Checking AppEngines 
  appengines.each { |appengine|
    log.debug "waiting until the appengine is running :#{appengine}"
    unless remote.pollAppEngine(appengine)
      write_event "poll App Engine Timeout: #{appengine}" 
      return
    end
  } 
  write_event("Spawn Application: #{application} with using #{datastore}")
  write_event "Application: (#{application}, #{datastore}) is running successfully" 
 
  # Start Console 
  remote.startConsole
  remote.sleep_until_port_is_open("bulls.cs.ucsb.edu", 7070)
  write_event "Starting Console is Completed at #{$config.console}" 
  write_event "Get Status of Console: #{remote.getConsoleStatus}" 
  
  test_id = `date +%Y%m%d%H`.chomp + "_" + application + "_" + datastore 
  5.times { |i| 
    # Start Agents  
    log.info remote.startAgents(application)
    sleep 1
    write_event "Starting Agents is Completed"

    log.info remote.sendStartToAgents
    sleep 180
    log.info remote.sendStopToAgents
    write_event "Test ##{i} is finished"
    
    #log.debug remote.getConsoleStatus 
    if datastore == "voldemort" and i != 4
      remote.spawnApp(application, datastore)
      appengines.each { |appengine|
        unless remote.pollAppEngine(appengine)
          write_event "poll App Engine Timeout: #{appengine}"; return
        end
      }
    else
      log.info remote.sendDeleteAllRecord(datastore)
    end
    # insert data to db and make one data log file
    log.info "insert Data2DB #{test_id} sample index: #{i}"
    remote.insertData2DB(test_id, i) 
  } 
  write_event "A set of tests is over"
  remote.stopConsole
  
  remote.initDataDirectory(test_id)
  write_event "InitDataDirectory ID: #{test_id}"      
  remote.sendLogFiles(test_id, application)
  write_event "Send Log Files ID: #{test_id}"      
  remote.processLogs(test_id, datastore, 3, 5)
  write_event "Process Logs ID: #{test_id}"      
  user, server = $config.repository.split('@')
  write_event "Test is processed see http://#{server}/#{test_id}" 
  
  sendNotification(remote, application, datastore, test_id)
end

OLD_PID = `ps -ef | grep AppBench | awk '{print $2}'`
KILL= `kill #{OLD_PID}`

#rebootAppScale(remote)
#datastores = ["mysql"] 
application, datastore = "petlog", "cassandra"
datastores = ["hbase", "hypertable", "cassandra", "voldemort", "mysql"] 
datastores.each { |datastore| 
  doTest(remote, application, datastore )
}




