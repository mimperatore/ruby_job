# frozen_string_literal: true

module RubyJob
  RSpec.describe InMemoryJobStore do
    let(:worker_class) do
      Class.new do
        include Worker

        def perform(_, _, _); end
      end
    end

    let(:now) { Time.at(Time.now.to_f.round(3)) }

    before(:each) do
      Timecop.freeze(now)
      MyWorker.jobstore = subject
    end

    around(:each) do |example|
      Object.const_set('MyWorker', worker_class)
      example.run
      Object.send(:remove_const, 'MyWorker')
    end

    describe '#enqueue' do
      it 'enqueues the specific jobs' do
        job1 = Job.new(worker_class_name: 'MyWorker', args: [], start_at: now + 3).enqueue
        job2 = Job.new(worker_class_name: 'MyWorker', args: [], start_at: now + 1).enqueue
        job3 = Job.new(worker_class_name: 'MyWorker', args: [], start_at: now + 2).enqueue
        Timecop.travel(now + 3)
        expect(subject.fetch).to eq(job2)
        expect(subject.fetch).to eq(job3)
        expect(subject.fetch).to eq(job1)
      end
    end

    describe '#dequeue' do
      it 'dequeues the specified jobs' do
        job1 = Job.new(worker_class_name: 'MyWorker', args: [], start_at: now + 3).enqueue
        job2 = Job.new(worker_class_name: 'MyWorker', args: [], start_at: now + 1).enqueue
        job3 = Job.new(worker_class_name: 'MyWorker', args: [], start_at: now + 2).enqueue
        job3.dequeue
        Timecop.travel(now + 4)
        expect(subject.fetch).to eq(job2)
        expect(subject.fetch).to eq(job1)
      end
    end

    describe '#pause_at' do
      it 'sets the pause_starting_at time' do
        subject.pause_at(now)
        expect(subject.pause_starting_at).to eq(now)
      end

      it 'sets the pause_starting_at time, even when nil' do
        subject.pause_at(nil)
        expect(subject.pause_starting_at).to eq(nil)
      end
    end

    describe '#fetch' do
      context 'wait: true' do
        before(:each) do
          subject.set(wait: true, wait_delay: 0.7)
        end

        it 'blocks when the jobstore is paused' do
          subject.pause_at(now + 1)
          Timecop.travel(now + 1)
          expect(subject).to receive(:sleep).with(0.7).and_wrap_original do |m, *args|
            # we know it wants to sleep; now let it not wait so fetch returns
            subject.set(wait: false)
            m.call(*args)
          end
          subject.fetch
        end

        it "waits until start_at (+/- the specified wait_delay:), if the next job's start_at is in the future" do
          job1 = Job.new(worker_class_name: 'MyWorker', args: [], start_at: now + 0.5).enqueue
          subject.set(wait: true, wait_delay: 0.1)
          expect(subject).to receive(:sleep).with(0.1).exactly(5).times.and_call_original
          Timecop.travel(now)
          expect(subject.fetch).to eq(job1)
          expect(Time.now).to be_within(0.1).of(job1.start_at)
        end
      end

      context 'wait: false' do
        before(:each) do
          subject.set(wait: false)
        end

        it 'returns nil when the jobstore is paused' do
          subject.pause_at(now + 1)
          Timecop.travel(now + 1)
          expect(subject.fetch).to be_nil
        end

        it "returns nil if the next job's start_at is in the future" do
          Job.new(worker_class_name: 'MyWorker', args: [], start_at: now + 0.001).enqueue
          expect(subject.fetch).to be_nil
        end

        it 'returns the next job when the appropriate time has come' do
          job1 = Job.new(worker_class_name: 'MyWorker', args: [], start_at: now + 2).enqueue
          expect(subject.fetch).to be_nil
          Timecop.freeze(now + 1.5)
          expect(subject.fetch).to be_nil
          Timecop.freeze(now + 2.5)
          expect(subject.fetch).to eq(job1)
        end
      end

      context 'start_at time correctness' do
        it 'returns the next job if its start_at is now' do
          job1 = Job.new(worker_class_name: 'MyWorker', args: [], start_at: now).enqueue
          expect(subject.fetch).to eq(job1)
        end

        it 'returns the next job if its start_at is in the past' do
          job1 = Job.new(worker_class_name: 'MyWorker', args: [], start_at: now - 0.001).enqueue
          expect(subject.fetch).to eq(job1)
        end
      end

      context 'order correctness' do
        it 'fetches jobs in increasing start_at order' do
          job1 = Job.new(worker_class_name: 'MyWorker', args: [], start_at: now + 3).enqueue
          job2 = Job.new(worker_class_name: 'MyWorker', args: [], start_at: now + 1).enqueue
          job3 = Job.new(worker_class_name: 'MyWorker', args: [], start_at: now + 2).enqueue
          Timecop.freeze(now + 3.5)
          expect(subject.fetch).to eq(job2)
          expect(subject.fetch).to eq(job3)
          expect(subject.fetch).to eq(job1)
        end
      end
    end

    describe '#size' do
      it 'returns the size of the job store' do
        Job.new(worker_class_name: 'MyWorker', args: [], start_at: now + 3).enqueue
        Job.new(worker_class_name: 'MyWorker', args: [], start_at: now + 1).enqueue
        Job.new(worker_class_name: 'MyWorker', args: [], start_at: now + 2).enqueue
        expect(subject.size).to eq(3)
      end
    end
  end
end
