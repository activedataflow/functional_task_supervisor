#!/usr/bin/env ruby

require 'bundler/setup'
require 'functional_task_supervisor'

# Example 1: Basic Task with Multiple Stages
puts "=" * 60
puts "Example 1: Basic Task with Multiple Stages"
puts "=" * 60

# Define a task with nested stage classes
class DataPipelineTask < FunctionalTaskSupervisor::Task
  class FetchData < FunctionalTaskSupervisor::Stage
    private

    def perform_work
      puts "  [#{name}] Fetching data from API..."
      sleep(0.5)
      task.data = { users: ['Alice', 'Bob', 'Charlie'] }
      Success(data: task.data)
    end
  end

  class ProcessData < FunctionalTaskSupervisor::Stage
    private

    def perform_work
      puts "  [#{name}] Processing data..."
      sleep(0.5)
      task.processed = { processed: true, count: task.data[:users].length }
      Success(data: task.processed)
    end
  end

  class SaveData < FunctionalTaskSupervisor::Stage
    private

    def perform_work
      puts "  [#{name}] Saving data to database..."
      sleep(0.5)
      Success(data: { saved: true, id: 123 })
    end
  end

  attr_accessor :data, :processed

  def stage_klass_sequence
    [FetchData, ProcessData, SaveData]
  end
end

task = DataPipelineTask.new
result = task.run

if result.success?
  puts "\n✓ Task completed successfully!"
  puts "  Completed stages: #{result.value![:completed].join(', ')}"
  puts "  Total stages: #{result.value![:total_stages]}"
else
  puts "\n✗ Task failed: #{result.failure}"
end

# Example 2: Task with Failure Handling
puts "\n" + "=" * 60
puts "Example 2: Task with Failure Handling"
puts "=" * 60

class FailingPipelineTask < FunctionalTaskSupervisor::Task
  class FetchData < FunctionalTaskSupervisor::Stage
    private

    def perform_work
      puts "  [#{name}] Fetching data from API..."
      sleep(0.5)
      Success(data: { users: ['Alice', 'Bob'] })
    end
  end

  class RiskyOperation < FunctionalTaskSupervisor::Stage
    private

    def perform_work
      puts "  [#{name}] Attempting risky operation..."
      sleep(0.5)
      Failure(error: 'Connection timeout', stage: name)
    end
  end

  class SaveData < FunctionalTaskSupervisor::Stage
    private

    def perform_work
      puts "  [#{name}] Saving data to database..."
      sleep(0.5)
      Success(data: { saved: true })
    end
  end

  def stage_klass_sequence
    [FetchData, RiskyOperation, SaveData]
  end
end

task2 = FailingPipelineTask.new
result2 = task2.run

if result2.success?
  puts "\n✓ Task completed successfully!"
else
  puts "\n✗ Task failed!"
  puts "  Error: #{result2.failure[:error]}"
  puts "  Failed at stage: #{result2.failure[:stage]}"
  puts "  Executed stages: #{task2.results.length}"
end

# Example 3: Custom Stage with Preconditions
puts "\n" + "=" * 60
puts "Example 3: Custom Stage with Preconditions"
puts "=" * 60

class ConditionalTask < FunctionalTaskSupervisor::Task
  class ConditionalStage < FunctionalTaskSupervisor::Stage
    private

    def preconditions_met?
      task.respond_to?(:condition_met?) ? task.condition_met? : true
    end

    def perform_work
      puts "  [#{name}] Executing conditional stage..."
      Success(data: 'conditional execution')
    end
  end

  class FailingConditionalStage < FunctionalTaskSupervisor::Stage
    private

    def preconditions_met?
      false  # Always fails precondition
    end

    def perform_work
      puts "  [#{name}] This should not be reached..."
      Success(data: 'should not happen')
    end
  end

  def stage_klass_sequence
    [ConditionalStage, FailingConditionalStage]
  end
end

task3 = ConditionalTask.new
result3 = task3.run

if result3.success?
  puts "\n✓ Task completed successfully!"
else
  puts "\n✗ Task failed!"
  puts "  Error: #{result3.failure[:error]}"
end

# Example 4: Stage State Inspection
puts "\n" + "=" * 60
puts "Example 4: Stage State Inspection"
puts "=" * 60

class InspectionTask < FunctionalTaskSupervisor::Task
  class InspectionStage < FunctionalTaskSupervisor::Stage
    private

    def perform_work
      Success(data: { inspected: true })
    end
  end

  def stage_klass_sequence
    [InspectionStage]
  end
end

inspection_task = InspectionTask.new
stage = FunctionalTaskSupervisor::Stage.new(task: inspection_task, name: 'inspection_test')

puts "Before execution:"
puts "  Performed? #{stage.performed?}"
puts "  Success? #{stage.success?}"
puts "  Failure? #{stage.failure?}"

stage.execute

puts "\nAfter execution:"
puts "  Performed? #{stage.performed?}"
puts "  Success? #{stage.success?}"
puts "  Failure? #{stage.failure?}"
puts "  Value: #{stage.value}"

# Example 5: Task Reset
puts "\n" + "=" * 60
puts "Example 5: Task Reset"
puts "=" * 60

class ResettableTask < FunctionalTaskSupervisor::Task
  class Stage1 < FunctionalTaskSupervisor::Stage
    private

    def perform_work
      puts "  [#{name}] Executing..."
      Success(data: 'stage1 complete')
    end
  end

  class Stage2 < FunctionalTaskSupervisor::Stage
    private

    def perform_work
      puts "  [#{name}] Executing..."
      Success(data: 'stage2 complete')
    end
  end

  def stage_klass_sequence
    [Stage1, Stage2]
  end
end

task5 = ResettableTask.new

puts "Running task first time..."
task5.run

puts "  Results count: #{task5.results.length}"
puts "  All successful? #{task5.all_successful?}"

puts "\nResetting task..."
task5.reset!

puts "  Results count after reset: #{task5.results.length}"
puts "  Executed stages after reset: #{task5.executed_stages.length}"

puts "\nRunning task second time..."
task5.run

puts "  Results count: #{task5.results.length}"
puts "  All successful? #{task5.all_successful?}"

puts "\n" + "=" * 60
puts "Examples completed!"
puts "=" * 60
