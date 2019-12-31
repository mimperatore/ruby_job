# frozen_string_literal: true

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
    let(:jobstore) { InMemoryJobStore.new }
    let(:jobs) do
      10.times.map { |i| RubyJob.new(worker_class_name: 'MyWorker', args: [], start_at: now + 0.01 * i) }
    end

    subject do
      described_class.new(num_threads, jobstore)
    end

    before(:each) do
      Timecop.freeze(now)
    end

    before(:each) do
      jobs.each { |job| jobstore.enqueue(job) }
    end

    around(:each) do |example|
      Object.const_set('MyWorker', worker_class)
      example.run
      Object.send(:remove_const, 'MyWorker')
    end

    describe '#start' do
      context 'single thread' do
        it 'eventually runs all jobs' do
          jobstore.to_a.each do |job|
            expect(job).to receive(:perform)
          end
          subject.stop_at(now + 1.5)
          Timecop.travel(now + 100)
          subject.start.join
        end
      end

      context 'multiple threads' do
        let(:num_threads) { 5 }

        it 'eventually runs all jobs' do
          jobstore.to_a.each do |job|
            expect(job).to receive(:perform)
          end
          subject.stop_at(now + 1.5)
          Timecop.travel(now + 100)
          subject.start.join
        end
      end
    end

    describe '#stop_at' do
      it 'stops processing jobs remaining in the jobstore with :start_at after the specified time' do
        subject.stop_at(now + 0.01 * 5)
        Timecop.travel(now + 100)
        subject.start(wait: true).join
        expect(jobstore.to_a).to match_array(jobs[6..9])
      end
    end

    describe '#stop' do
      it 'behaves like #stop_at(Time.now)' do
        expect(subject).to receive(:stop_at).with(Time.now)
        subject.stop
      end
    end
  end
end
