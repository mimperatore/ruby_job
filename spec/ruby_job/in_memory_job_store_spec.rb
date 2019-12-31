# frozen_string_literal: true

module RubyJob
  RSpec.describe InMemoryJobStore do
    let(:worker_class) do
      Class.new do
        include Worker

        def perform(_, _, _); end

        def self.jobstore; end
      end
    end

    let(:now) { Time.now }

    before(:each) do
      Timecop.freeze(now)
    end

    around(:each) do |example|
      Object.const_set('MyWorker', worker_class)
      example.run
      Object.send(:remove_const, 'MyWorker')
    end

    describe '#enqueue' do
      it 'enqueues the specifiec jobs' do
        job1 = RubyJob.new(worker_class_name: 'MyWorker', args: [], start_at: Time.now + 3)
        job2 = RubyJob.new(worker_class_name: 'MyWorker', args: [], start_at: Time.now + 1)
        job3 = RubyJob.new(worker_class_name: 'MyWorker', args: [], start_at: Time.now + 2)
        subject.enqueue(job1)
        subject.enqueue(job2)
        subject.enqueue(job3)
        expect(subject.to_a).to match_array([job1, job2, job3])
      end
    end

    describe '#dequeue' do
      it 'dequeues the specified jobs' do
        job1 = RubyJob.new(worker_class_name: 'MyWorker', args: [], start_at: Time.now + 3)
        job2 = RubyJob.new(worker_class_name: 'MyWorker', args: [], start_at: Time.now + 1)
        job3 = RubyJob.new(worker_class_name: 'MyWorker', args: [], start_at: Time.now + 2)
        subject.enqueue(job1)
        subject.enqueue(job2)
        subject.enqueue(job3)
        subject.dequeue(job3)
        expect(subject.to_a).to match_array([job1, job2])
      end
    end

    describe '#pause_at' do
      it 'sets the pause_starting_at time' do
        subject.pause_at(now + 1.5)
        expect(subject.pause_starting_at).to eq(now + 1.5)
      end
    end

    describe '#fetch' do
      context 'paused' do
        it 'returns nil when the jobstore is paused' do
          subject.pause_at(now)
          expect(subject.fetch(wait: true, delay: 0.1)).to be_nil
          expect(subject.fetch(wait: false)).to be_nil
        end
      end

      context 'wait: true' do
        it "waits until start_at (+/- the specified delay:), if the next job's start_at is in the future" do
          job1 = RubyJob.new(worker_class_name: 'MyWorker', args: [], start_at: Time.now + 0.25)
          Timecop.travel(now)
          subject.enqueue(job1)
          expect(subject.fetch(wait: true, delay: 0.1)).to eq(job1)
          expect(Time.now).to be_within(0.1).of(job1.start_at)
        end
      end

      context 'wait: false' do
        it "returns nil if the next job's start_at is in the future" do
          job1 = RubyJob.new(worker_class_name: 'MyWorker', args: [], start_at: Time.now + 0.001)
          subject.enqueue(job1)
          expect(subject.fetch(wait: false)).to be_nil
        end

        it 'returns the next job when the appropriate time has come' do
          job1 = RubyJob.new(worker_class_name: 'MyWorker', args: [], start_at: Time.now + 2)
          subject.enqueue(job1)
          expect(subject.fetch(wait: false)).to be_nil
          Timecop.freeze(now + 1)
          expect(subject.fetch(wait: false)).to be_nil
          Timecop.freeze(now + 2)
          expect(subject.fetch(wait: false)).to eq(job1)
        end
      end

      context 'start_at time correctness' do
        it 'returns the next job if its start_at is now' do
          job1 = RubyJob.new(worker_class_name: 'MyWorker', args: [], start_at: Time.now)
          subject.enqueue(job1)
          expect(subject.fetch).to eq(job1)
        end

        it 'returns the next job if its start_at is in the past' do
          job1 = RubyJob.new(worker_class_name: 'MyWorker', args: [], start_at: Time.now - 0.001)
          subject.enqueue(job1)
          expect(subject.fetch).to eq(job1)
        end
      end

      context 'order correctness' do
        it 'fetches jobs in increasing start_at order' do
          job1 = RubyJob.new(worker_class_name: 'MyWorker', args: [], start_at: Time.now + 3)
          job2 = RubyJob.new(worker_class_name: 'MyWorker', args: [], start_at: Time.now + 1)
          job3 = RubyJob.new(worker_class_name: 'MyWorker', args: [], start_at: Time.now + 2)
          subject.enqueue(job1)
          subject.enqueue(job2)
          subject.enqueue(job3)
          Timecop.freeze(now + 3)
          expect(subject.fetch).to eq(job2)
          expect(subject.fetch).to eq(job3)
          expect(subject.fetch).to eq(job1)
        end
      end
    end

    describe '#size' do
      it 'returns the size of the job store' do
        job1 = RubyJob.new(worker_class_name: 'MyWorker', args: [], start_at: Time.now + 3)
        job2 = RubyJob.new(worker_class_name: 'MyWorker', args: [], start_at: Time.now + 1)
        job3 = RubyJob.new(worker_class_name: 'MyWorker', args: [], start_at: Time.now + 2)
        subject.enqueue(job1)
        subject.enqueue(job2)
        subject.enqueue(job3)
        subject.dequeue(job3)
        expect(subject.size).to eq(2)
      end
    end

    describe '#to_a' do
      it 'returns the set of jobs as an array' do
        job1 = RubyJob.new(worker_class_name: 'MyWorker', args: [], start_at: Time.now + 3)
        job2 = RubyJob.new(worker_class_name: 'MyWorker', args: [], start_at: Time.now + 1)
        job3 = RubyJob.new(worker_class_name: 'MyWorker', args: [], start_at: Time.now + 2)
        subject.enqueue(job1)
        subject.enqueue(job2)
        subject.enqueue(job3)
        expect(subject.to_a).to match_array([job1, job2, job3])
      end
    end
  end
end
