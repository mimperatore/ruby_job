# frozen_string_literal: true

require 'yaml'

module RubyJob
  RSpec.describe ThreadedServer do
    let(:worker_class) do
      Class.new do
        include Worker

        def perform; end
      end
    end

    let(:now) { Time.now }
    let(:num_threads) { 1 }
    let(:num_jobs) { 1 }
    let(:jobstore) { InMemoryJobStore.new }
    let(:jobs) { num_jobs.times.map { MyWorker.perform_async } }

    subject do
      described_class.new(num_threads, jobstore)
    end

    before(:each) do
      Timecop.freeze(now)
    end

    before(:each) do
      MyWorker.jobstore = jobstore
      starting_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      jobs
      ending_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      delta = ending_time - starting_time
      puts "- created #{num_jobs} in #{delta} seconds"
    end

    around(:each) do |example|
      Object.const_set('MyWorker', worker_class)
      example.run
      Object.send(:remove_const, 'MyWorker')
    end

    EXPECTED_PERFORMANCE = YAML.load_file(__FILE__.gsub(/.rb$/, '.expectations'))['performance']

    [10_000, 100_000].each do |j|
      describe "#{j} jobs", performance: true do
        [10].each do |t|
          context "number of threads: #{t}" do
            let(:num_threads) { t }
            let(:num_jobs) { j }

            (ENV['CI'] == 'true' ? 'ci' : 'test').tap do |env|
              it "processes everything in under #{EXPECTED_PERFORMANCE["#{j}/#{t}/#{env}"]} seconds" do
                subject.stop_at(now + 100)
                Timecop.travel(now + 100)
                starting_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
                subject.start.join
                ending_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
                delta = ending_time - starting_time
                expect(jobstore.size).to eq(0)
                puts "- #{j}/#{t}/#{env} took #{delta} seconds"
                expect(delta).to be < EXPECTED_PERFORMANCE["#{j}/#{t}/#{env}"].to_f
              end
            end
          end
        end
      end
    end
  end
end
