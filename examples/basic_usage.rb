#!/usr/bin/env ruby

require 'bundler/setup'
require 'functional_task_supervisor'

# Example 1: Basic Task with Multiple Stages
puts "=" * 60
puts "Example 1: Basic Task with Multiple Stages"
puts "=" * 60

class FetchDataStage < FunctionalTaskSupervisor::Stage
  private

  def perform_work
    puts "  [#{name}] Fetching data from API..."
    sleep(0.5)
    data = { users: ['Alice', 'Bob', 'Charlie'] }
    Success(data: data)
  end
end

class ProcessDataStage < FunctionalTaskSupervisor::Stage
  private

  def perform_work
    puts "  [#{name}] Processing data..."
    sleep(0.5)
    Success(data: { processed: true, count: 3 })
  end
end

class SaveDataStage < FunctionalTaskSupervisor::Stage
  private

  def perform_work
    puts "  [#{name}] Saving data to database..."
    sleep(0.5)
    Success(data: { saved: true, id: 123 })
  end
end

task = FunctionalTaskSupervisor::Task.new
task.add_stage(FetchDataStage.new('fetch'))
    .add_stage(ProcessDataStage.new('process'))
    .add_stage(SaveDataStage.new('save'))

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

class FailingStage < FunctionalTaskSupervisor::Stage
  private

  def perform_work
    puts "  [#{name}] Attempting risky operation..."
    sleep(0.5)
    Failure(error: 'Connection timeout', stage: name)
  end
end

task2 = FunctionalTaskSupervisor::Task.new
task2.add_stage(FetchDataStage.new('fetch'))
     .add_stage(FailingStage.new('risky_operation'))
     .add_stage(SaveDataStage.new('save'))

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

class ConditionalStage < FunctionalTaskSupervisor::Stage
  attr_accessor :condition

  def initialize(name, condition: true)
    super(name)
    @condition = condition
  end

  private

  def preconditions_met?
    @condition
  end

  def perform_work
    puts "  [#{name}] Executing conditional stage..."
    Success(data: 'conditional execution')
  end
end

task3 = FunctionalTaskSupervisor::Task.new
task3.add_stage(ConditionalStage.new('conditional1', condition: true))
     .add_stage(ConditionalStage.new('conditional2', condition: false))

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

stage = FetchDataStage.new('inspection_test')

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

task5 = FunctionalTaskSupervisor::Task.new
task5.add_stage(FetchDataStage.new('fetch'))
     .add_stage(ProcessDataStage.new('process'))

puts "Running task first time..."
task5.run

puts "  Results count: #{task5.results.length}"
puts "  All successful? #{task5.all_successful?}"

puts "\nResetting task..."
task5.reset!

puts "  Results count after reset: #{task5.results.length}"
puts "  Stages performed? #{task5.stages.any?(&:performed?)}"

puts "\nRunning task second time..."
task5.run

puts "  Results count: #{task5.results.length}"
puts "  All successful? #{task5.all_successful?}"

puts "\n" + "=" * 60
puts "Examples completed!"
puts "=" * 60
