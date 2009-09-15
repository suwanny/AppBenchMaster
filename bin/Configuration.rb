class Configuration
  attr_reader :appscale, :console, :agents, :repository
  attr_writer :appscale, :console, :agents, :repository

  def initialize(appscale, console, agents, repository)
    @appscale = appscale
    @console = console
    @agents = agents
    @repository = repository
  end
end
