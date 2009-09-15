#!/usr/bin/ruby 

require "yaml"
require "Configuration"

appscale = "root@128.111.55.227"
console = "spark2007@bulls.cs.ucsb.edu" # remote console port 7070
agents = ["spark2007@bulls.cs.ucsb.edu", "spark2007@lakers.cs.ucsb.edu", "spark2007@wizards.cs.ucsb.edu"]
repository = "spark2007@bulls.cs.ucsb.edu"

config = Configuration.new(appscale, console, agents, repository)

File.open( 'config.yaml', 'w' ) do |out|
  YAML.dump(config, out)
end

  
