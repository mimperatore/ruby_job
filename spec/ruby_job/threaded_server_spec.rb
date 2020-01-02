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
      10.times.map { |i| MyWorker.perform_at(now + i) }
    end

    subject do
      described_class.new(num_threads, jobstore)
    end

    before(:each) do
      Timecop.freeze(now)
    end

    before(:each) do
      MyWorker.jobstore = jobstore
      jobs
    end

    around(:each) do |example|
      Object.const_set('MyWorker', worker_class)
      example.run
      Object.send(:remove_const, 'MyWorker')
    end

    describe '#start' do
      before(:each) do
        jobs.each do |job|
          expect(job).to receive(:perform)
        end
      end

      context 'single thread' do
        it 'eventually runs all jobs' do
          subject.stop_at(now + 15)
          Timecop.travel(now + 100)
          subject.start.join
        end
      end

      context 'multiple threads' do
        let(:num_threads) { 5 }

        it 'eventually runs all jobs' do
          subject.stop_at(now + 15)
          Timecop.travel(now + 100)
          subject.start.join
        end
      end
    end

    describe '#stop_at' do
      it 'instructs the jobstore to stop processing jobs as of the specified time' do
        expect(jobstore).to receive(:pause_at).with(now)
        subject.stop_at(now)
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
