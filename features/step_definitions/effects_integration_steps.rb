Given('I have a task with state tracking') do
  task_class = Class.new(FunctionalTaskSupervisor::Task) do
    include FunctionalTaskSupervisor::Effects::StateHandler
  end
  @task = task_class.new
end

Given('I have a task with dependency injection') do
  @task = FunctionalTaskSupervisor::Task.new
  @logger = double('Logger', info: nil, error: nil, warn: nil, debug: nil)
end

Given('I have a task with combined effects') do
  task_class = Class.new(FunctionalTaskSupervisor::Task) do
    include FunctionalTaskSupervisor::Effects::StateHandler
  end
  @task = task_class.new
  @logger = double('Logger', info: nil, error: nil, warn: nil, debug: nil)
end

Given('I add a stage that uses logger') do
  stage_class = Class.new(FunctionalTaskSupervisor::Stage) do
    include FunctionalTaskSupervisor::Effects::ResolveHandler

    private

    def perform_work
      log('Executing stage')
      Dry::Monads::Success(data: 'completed')
    end
  end
  @stage = stage_class.new('logging_stage')
  @task.add_stage(@stage)
end

Given('I add stages that use dependencies and state') do
  stage_class = Class.new(FunctionalTaskSupervisor::Stage) do
    include FunctionalTaskSupervisor::Effects::ResolveHandler

    private

    def perform_work
      log('Processing')
      Dry::Monads::Success(data: 'done')
    end
  end

  @task.add_stage(stage_class.new('stage1'))
  @task.add_stage(stage_class.new('stage2'))
end

Given('I add a failing stage with logging') do
  stage_class = Class.new(FunctionalTaskSupervisor::Stage) do
    include FunctionalTaskSupervisor::Effects::ResolveHandler

    private

    def perform_work
      log('About to fail', level: :error)
      Dry::Monads::Failure(error: 'Intentional failure')
    end
  end
  @failing_stage = stage_class.new('failing_stage')
  @task.add_stage(@failing_stage)
end

When('I run the task with state handler') do
  @runner = FunctionalTaskSupervisor::Effects::StateTaskRunner.new
  @handler_result = @runner.call(@task)
end

When('I run the task with dependency provider') do
  @provider = FunctionalTaskSupervisor::Effects::DependencyProvider.new(logger: @logger)
  @handler_result = @provider.call(@task)
end

When('I run the task with combined handler') do
  @runner = FunctionalTaskSupervisor::Effects::TaskRunner.new(logger: @logger)
  @handler_result = @runner.call(@task)
end

Then('the execution history should contain all stage names') do
  history = @handler_result[:history]
  expected_names = @task.stages.map(&:name)
  expect(history).to eq(expected_names)
end

Then('the metadata should track each stage execution') do
  metadata = @handler_result[:metadata]
  @task.stages.each do |stage|
    expect(metadata).to have_key(stage.name)
    expect(metadata[stage.name]).to include(:index, :success, :timestamp)
  end
end

Then('the stage should have access to the logger') do
  expect(@handler_result).to be_success
end

Then('the logger should record stage execution') do
  expect(@logger).to have_received(:info).with('[logging_stage] Executing stage')
end

Then('the history should be tracked') do
  expect(@handler_result[:history]).not_to be_empty
end

Then('the dependencies should be available') do
  expect(@logger).to have_received(:info).at_least(:once)
end

Then('all effects should work together') do
  expect(@handler_result[:history]).not_to be_empty
  expect(@handler_result[:metadata]).not_to be_empty
  expect(@handler_result[:result]).to be_success
end

Then('the failure should be tracked in metadata') do
  metadata = @handler_result[:metadata]
  expect(metadata['failing_stage'][:success]).to be false
end

Then('the failure should be logged') do
  expect(@logger).to have_received(:error).with('[failing_stage] About to fail')
end
