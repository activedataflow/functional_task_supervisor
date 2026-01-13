Given('I have a task') do
  create_task
end

Given('I add a stage named {string}') do |stage_name|
  stage = create_stage(stage_name)
  add_stage_to_task(stage)
end

Given('I add a failing stage named {string}') do |stage_name|
  stage = create_custom_stage(stage_name) do
    Dry::Monads::Failure(error: 'Stage failed', stage: stage_name)
  end
  add_stage_to_task(stage)
end

Given('I add a custom stage that returns specific data') do
  @custom_data = { custom: 'data', value: 42 }
  stage = create_custom_stage('custom_stage') do
    Dry::Monads::Success(@custom_data)
  end
  add_stage_to_task(stage)
end

When('I run the task') do
  run_task
end

When('I run the task ignoring errors') do
  begin
    run_task
  rescue StandardError
    # Ignore errors for testing
  end
end

When('I reset the task') do
  task.reset!
end

Then('the task should complete successfully') do
  expect(task_result).to be_success
end

Then('the task should fail') do
  expect(task_result).to be_failure
end

Then('all stages should be executed') do
  expect(task.stages.all?(&:performed?)).to be true
end

Then('the result should include all stage names') do
  stage_names = task_result.value![:completed]
  expected_names = task.stages.map(&:name)
  expect(stage_names).to eq(expected_names)
end

Then('only executed stages should be in results') do
  expect(task.results).not_to be_empty
  expect(task.results.length).to be <= task.stages.length
end

Then('the stage {string} should be marked as performed') do |stage_name|
  stage = task.stages.find { |s| s.name == stage_name }
  expect(stage.performed?).to be true
end

Then('the stage {string} should be successful') do |stage_name|
  stage = task.stages.find { |s| s.name == stage_name }
  expect(stage.success?).to be true
end

Then('no stages should be marked as performed') do
  expect(task.stages.none?(&:performed?)).to be true
end

Then('the results should be empty') do
  expect(task.results).to be_empty
end

Then('I should have both successful and failed results') do
  expect(task.successful_results).not_to be_empty
  expect(task.failed_results).not_to be_empty
end

Then('the task should report failures') do
  expect(task.any_failed?).to be true
end

Then('the stage should return the custom data') do
  stage_result = task.results.first
  expect(stage_result.value!).to eq(@custom_data)
end
