#!/usr/bin/ruby

require "yaml"
require "Configuration" 

config = YAML.load_file("config.yaml")

puts "config:"
#puts config

puts "appscale: #{config.appscale}"
puts "console: #{config.console}"
puts "agents: "
config.agents.each { |agent| puts "\t #{agent}"; }
puts "repository: #{config.repository}"

