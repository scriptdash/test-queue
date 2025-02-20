# frozen_string_literal: true

require 'rspec/core'

raise 'requires RSpec version 3 or 4' unless [3, 4].include?(RSpec::Core::Version::STRING.to_i)

require_relative 'rspec_ext'
require_relative '../runner'

module TestQueue
  class Runner
    class RSpec < Runner
      def initialize
        super(TestFramework::RSpec.new)
      end

      def run_worker(iterator)
        rspec = ::RSpec::Core::QueueRunner.new
        rspec.run_each(iterator).to_i
      end

      def summarize_worker(worker)
        worker.summary = worker.lines.grep(/ examples?, /).first
        worker.failure_output = worker.output[/^Failures:\n\n(.*)\n^Finished/m, 1]
      end
    end
  end

  class TestFramework
    class RSpec < TestFramework
      begin
        require 'turnip/rspec'

        include Turnip::RSpec::Loader
      rescue LoadError
        # noop
      end

      def all_suite_files
        options = ::RSpec::Core::ConfigurationOptions.new(ARGV)
        options.parse_options if options.respond_to?(:parse_options)
        options.configure(::RSpec.configuration)

        if ::RSpec.configuration.instance_variable_defined?(:@files_or_directories_to_run) &&
           ::RSpec.configuration.instance_variable_get(:@files_or_directories_to_run).empty?
          ::RSpec.configuration.instance_variable_set(:@files_or_directories_to_run, [::RSpec.configuration.default_path])
        end

        ::RSpec.configuration.files_to_run.uniq
      end

      def suites_from_file(path)
        ::RSpec.world.example_groups.clear
        load path
        split_groups(::RSpec.world.example_groups).map { |example_or_group|
          name = if example_or_group.respond_to?(:id)
                   example_or_group.id
                 elsif example_or_group.respond_to?(:full_description)
                   example_or_group.full_description
                 elsif example_or_group.metadata.key?(:full_description)
                   example_or_group.metadata[:full_description]
                 else
                   example_or_group.metadata[:example_group][:full_description]
                 end
          [name, example_or_group]
        }
      end

      private

      def split_groups(groups)
        return groups unless split_groups?

        groups_to_split, groups_to_keep = [], []
        groups.each do |group|
          (group.metadata[:no_split] ? groups_to_keep : groups_to_split) << group
        end
        queue = groups_to_split.flat_map(&:descendant_filtered_examples)
        queue.concat groups_to_keep
        queue
      end

      def split_groups?
        return @split_groups if defined?(@split_groups)

        @split_groups = ENV['TEST_QUEUE_SPLIT_GROUPS'] && ENV['TEST_QUEUE_SPLIT_GROUPS'].strip.downcase == 'true'
      end
    end
  end
end
