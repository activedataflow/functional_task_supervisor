require 'functional_task_supervisor'
require 'dry/monads'
require 'dry/effects'

# Cucumber world extensions
module TaskWorld
  def create_task
    @task = FunctionalTaskSupervisor::Task.new
  end

  def create_stage(name)
    FunctionalTaskSupervisor::Stage.new(name)
  end

  def create_custom_stage(name, &block)
    stage_class = Class.new(FunctionalTaskSupervisor::Stage) do
      define_method(:perform_work, &block)
    end
    stage_class.new(name)
  end

  def add_stage_to_task(stage)
    @task.add_stage(stage)
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
