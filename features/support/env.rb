require 'functional_task_supervisor'
require 'dry/monads'
require 'dry/effects'

# A dynamic task class that allows adding stage classes at runtime
# This is used for testing purposes in cucumber scenarios
class DynamicTask < FunctionalTaskSupervisor::Task
  def initialize
    super
    @stage_classes = []
  end

  def add_stage_class(stage_class)
    @stage_classes << stage_class
    self
  end

  def stage_klass_sequence
    @stage_classes
  end
end

class DynamicTaskWithState < DynamicTask
  include FunctionalTaskSupervisor::Effects::StateHandler
end

# Cucumber world extensions
module TaskWorld
  def create_task
    @task = DynamicTask.new
  end

  def create_task_with_state
    @task = DynamicTaskWithState.new
  end

  def create_stage_class(name)
    stage_name = name
    Class.new(FunctionalTaskSupervisor::Stage) do
      define_singleton_method(:stage_name) { stage_name }

      define_method(:initialize) do |task:|
        super(task: task, name: stage_name)
      end
    end
  end

  def create_custom_stage_class(name, &block)
    stage_name = name
    Class.new(FunctionalTaskSupervisor::Stage) do
      define_singleton_method(:stage_name) { stage_name }

      define_method(:initialize) do |task:|
        super(task: task, name: stage_name)
      end

      private

      define_method(:perform_work, &block)
    end
  end

  def add_stage_class_to_task(stage_class)
    @task.add_stage_class(stage_class)
  end

  def run_task
    @result = @task.run
  end

  def task_result
    @result
  end

  def task
    @task
  end
end

World(TaskWorld)
