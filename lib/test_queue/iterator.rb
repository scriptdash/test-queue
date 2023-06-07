# frozen_string_literal: true

module TestQueue
  class Iterator
    include Enumerable

    attr_reader :client

    def initialize(test_framework, transport, filter = nil, run_token:, early_failure_limit: nil)
      @test_framework = test_framework
      @done = false
      @suite_stats = []
      @client = Transport.client(transport, run_token)
      @filter = filter
      @failures = 0
      @early_failure_limit = early_failure_limit
    end

    def each
      raise "already used this iterator. previous caller: #{@done}" if @done

      procline = $0

      loop do
        # If we've hit too many failures in one worker, assume the entire
        # test suite is broken, and notify master so the run
        # can be immediately halted.
        if @early_failure_limit && @failures >= @early_failure_limit
          client.kaboom
          break
        else
          item = client.pop
        end
        break if item.nil? || item.empty?

        if item == 'WAIT'
          $0 = "#{procline} - Waiting for work"
          sleep 0.1
          next
        end
        suite_name, path = item
        suite = load_suite(suite_name, path)

        # Maybe we were told to load a suite that doesn't exist anymore.
        next unless suite

        $0 = "#{procline} - #{suite.respond_to?(:description) ? suite.description : suite}"
        start = Time.now
        if @filter
          @filter.call(suite) { yield suite }
        else
          yield suite
        end
        @suite_stats << TestQueue::Stats::Suite.new(suite_name, path, Time.now - start, Time.now)
        @failures += suite.failure_count if suite.respond_to? :failure_count
      end
    ensure
      $0 = procline
      @done = caller(1..1).first
      File.open("/tmp/test_queue_worker_#{$$}_suites", 'wb') do |f|
        Marshal.dump(@suite_stats, f)
      end
    end

    def empty?
      false
    end

    def load_suite(suite_name, path)
      @loaded_suites ||= {}
      suite = @loaded_suites[suite_name]
      return suite if suite

      @test_framework.suites_from_file(path).each do |name, suite_from_file|
        @loaded_suites[name] = suite_from_file
      end
      @loaded_suites[suite_name]
    end
  end
end
