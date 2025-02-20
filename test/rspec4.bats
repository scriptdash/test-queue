load "testlib"

setup() {
  require_gem "rspec" "4.0.0.pre"
}

@test "rspec-queue succeeds when all specs pass" {
  run bundle exec rspec-queue ./test/examples/example_spec.rb
  assert_status 0
  assert_output_contains "Starting test-queue master"
  assert_output_contains "16 examples, 0 failures"
  assert_output_contains "16 examples, 0 failures"
}

@test "rspec-queue succeeds all specs pass in the default spec directory even if directory path is omitted" {
  run bundle exec rspec-queue
  assert_status 0
  assert_output_contains "Starting test-queue master"
  assert_output_contains "6 examples, 0 failures"
  assert_output_contains "0 examples, 0 failures"
}

@test "rspec-queue fails when a spec fails" {
  export FAIL=1
  run bundle exec rspec-queue ./test/examples/example_spec.rb
  assert_status 1
  assert_output_contains "1) RSpecFailure fails"
  assert_output_contains "RSpecFailure fails"
  assert_output_contains "expected: :bar"
  assert_output_contains "got: :foo"
}

@test "TEST_QUEUE_SPLIT_GROUPS splits splittable groups" {
  export TEST_QUEUE_SPLIT_GROUPS=true
  run bundle exec rspec-queue ./test/examples/example_split_spec.rb
  assert_status 0

  assert_output_matches '\[ 1\] +1 example, 0 failures'
  assert_output_matches '\[ 2\] +1 example, 0 failures'
}

@test "TEST_QUEUE_SPLIT_GROUPS does not split unsplittable groups" {
  export TEST_QUEUE_SPLIT_GROUPS=true
  export NOSPLIT=1
  run bundle exec rspec-queue ./test/examples/example_split_spec.rb
  assert_status 0

  assert_output_contains "2 examples, 0 failures"
  assert_output_contains "0 examples, 0 failures"
}

@test "rspec-queue supports shared example groups" {
  run bundle exec rspec-queue ./test/examples/example_use_shared_example1_spec.rb \
                              ./test/examples/example_use_shared_example2_spec.rb
  assert_status 0
}
