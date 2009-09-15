#!/usr/bin/ruby -w

stat0 = ''
stat1 = 'Agent bulls [Connected], Agent lakers [Connected], Agent wizards [Connected]'
stat2 = '<no connected agents>'
stat3 = 'Agent bulls (Agent 0) [Connected] { Worker bulls-0 [Running (1/1 threads)] }, Agent lakers (Agent 1) [Connected] { Worker lakers-0 [Running (1/1 threads)] }, Agent wizards (Agent 2) [Connected] { Worker wizards-0 [Running (1/1 threads)] }'
stat4 = 'Agent bulls (Agent 0) [Connected], Agent lakers (Agent 1) [Connected], Agent wizards (Agent 2) [Connected]'

def getStatus(str, num_agent = 3)
  puts str
  return "INIT" if str.length == 0
  agents = str.split(',')
  return "INIT" if agents.length < num_agent

  agents.each { |agent| 
    agent_info = agent.split()
    return "WORKING" if agent.index("Worker")
  }
  return "CONNECTED" if str.index("Connected")
end

stat_list = [stat0, stat1, stat2, stat3, stat4]
stat_list.each { |stat| 
  puts getStatus(stat)
}

