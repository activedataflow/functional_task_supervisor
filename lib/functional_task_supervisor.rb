require 'dry/monads'
require 'dry/effects'

require_relative 'functional_task_supervisor/version'
require_relative 'functional_task_supervisor/stage'
require_relative 'functional_task_supervisor/task'
require_relative 'functional_task_supervisor/effects/state_handler'
require_relative 'functional_task_supervisor/effects/resolve_handler'

module FunctionalTaskSupervisor
  class Error < StandardError; end

  # Convenience method to create a new task
  def self.new_task
    Task.new
  end

  # Convenience method to create a new stage
  def self.new_stage(name)
    Stage.new(name)
  end
end
