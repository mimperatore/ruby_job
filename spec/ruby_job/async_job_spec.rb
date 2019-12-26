# frozen_string_literal: true

module RubyJob
  RSpec.describe Job do
    let(:worker_class) do
      Class.new do
        include Worker

        def perform(_, _, _); end

        def self.jobstore; end
      end
    end

    around(:each) do |example|
      Object.const_set('MyWorker', worker_class)
      example.run
      Object.send(:remove_const, 'MyWorker')
    end

    before(:each) do
      Timecop.freeze(Time.now)
    end

    let(:worker_class_name) { 'MyWorker' }
    let(:args) { [1] }
    let(:start_at) { Time.now }
    let(:expected_hash) do
      {
        'json_class' => described_class.name,
        'data' => {
          'worker_class_name' => worker_class_name,
          'args_json' => JSON.dump(args),
          'start_at' => start_at.iso8601(9)
        }
      }
    end

    subject { described_class.new(worker_class_name: worker_class_name, args: args, start_at: start_at) }

    describe '#initialize' do
      it 'defaults start_time to Time.now' do
        job_without_start_at = described_class.new(worker_class_name: worker_class_name, args: args)
        expect(job_without_start_at.start_at).to eq(Time.now)
      end

      it "defaults jobstore to the worker class' jobstore, if it exists" do
        myworker_jobstore = double('jobstore')
        allow(MyWorker).to receive(:jobstore).and_return(myworker_jobstore)
        job = described_class.new(worker_class_name: worker_class_name, args: args)
        expect(job.jobstore).to eq(myworker_jobstore)
      end

      it "defaults jobstore to Worker.jobstore, if it doesn't exist in the worker class" do
        worker_jobstore = double('worker jobstore')
        allow(Worker).to receive(:jobstore).and_return(worker_jobstore)
        allow(MyWorker).to receive(:respond_to?).with(:jobstore).and_return(nil)
        job = described_class.new(worker_class_name: worker_class_name, args: args)
        expect(job.jobstore).to eq(worker_jobstore)
      end
    end

    describe '#==' do
      context 'equality' do
        it 'compares equal objects correctly' do
          other = described_class.new(worker_class_name: worker_class_name, args: args, start_at: start_at)
          expect(subject).to eq(other)
        end

        it 'compares equal objects correctly when args are nil' do
          obj1 = described_class.new(worker_class_name: worker_class_name, args: nil, start_at: start_at)
          obj2 = described_class.new(worker_class_name: worker_class_name, args: nil, start_at: start_at)
          expect(obj1).to eq(obj2)
        end
      end

      context 'inequality' do
        it 'compares non-equal objects correctly (different worker_class_name)' do
          other = described_class.new(worker_class_name: 'Object', args: args, start_at: start_at)
          expect(subject).not_to eq(other)
        end

        it 'compares non-equal objects correctly (different args)' do
          other = described_class.new(worker_class_name: worker_class_name, args: [2], start_at: start_at)
          expect(subject).not_to eq(other)
        end

        it 'compares non-equal objects correctly (one nil arg)' do
          other = described_class.new(worker_class_name: worker_class_name, args: nil, start_at: start_at)
          expect(subject).not_to eq(other)
        end

        it 'compares non-equal objects correctly (different start_at)' do
          other = described_class.new(worker_class_name: worker_class_name, args: args, start_at: start_at + 1)
          expect(subject).not_to eq(other)
        end
      end
    end

    describe '#to_h' do
      it 'returns a hash representation of the object' do
        expect(subject.to_h).to eq(expected_hash)
      end
    end

    describe '#to_json' do
      it 'returns the json encoding of #to_h, with the specified options' do
        options = double('options')
        hash = double('hash')
        json = double('json')
        expect(subject).to receive(:to_h).and_return(hash)
        expect(hash).to receive(:to_json).with(options).and_return(json)
        expect(subject.to_json(options)).to eq(json)
      end
    end

    describe '.json_create' do
      it 'returns a Job from the specified hash' do
        expect(Job.json_create(JSON.parse(subject.to_json))).to eq(subject)
      end
    end

    describe '#enqueue' do
      let(:jobstore) { JobStore.new }

      before(:each) do
        allow(MyWorker).to receive(:jobstore).and_return(jobstore)
        allow(jobstore).to receive(:enqueue).with(subject)
      end

      it 'enqueues the job into the jobstore' do
        expect(jobstore).to receive(:enqueue).with(subject)
        subject.enqueue
      end

      it 'raises an error if the job has already been enqueued' do
        subject.enqueue
        expect { subject.enqueue }.to raise_error(RuntimeError, /already been enqueued/)
      end

      it "returns what the jobstore's #enqueue method returns" do
        allow(jobstore).to receive(:enqueue).and_return(7)
        expect(subject.enqueue).to eq(7)
      end
    end

    describe '#dequeue' do
      let(:jobstore) { JobStore.new }

      before(:each) do
        allow(MyWorker).to receive(:jobstore).and_return(jobstore)
        allow(jobstore).to receive(:enqueue).with(subject)
        allow(jobstore).to receive(:dequeue).with(subject)
      end

      it 'dequeues the job from the jobstore' do
        subject.enqueue
        expect(jobstore).to receive(:dequeue).with(subject)
        subject.dequeue
      end

      it 'raises an error if the job has not been enqueued' do
        expect { subject.dequeue }.to raise_error(RuntimeError, /not queued/)
      end

      it 'raises an error if the job has alrady been dequeued' do
        subject.enqueue
        subject.dequeue
        expect { subject.dequeue }.to raise_error(RuntimeError, /not queued/)
      end

      it "returns what the jobstore's #dequeue method returns" do
        subject.enqueue
        allow(jobstore).to receive(:dequeue).and_return(7)
        expect(subject.dequeue).to eq(7)
      end
    end

    describe '#fetch' do
      let(:jobstore) { JobStore.new }

      before(:each) do
        allow(MyWorker).to receive(:jobstore).and_return(jobstore)
        allow(jobstore).to receive(:fetch)
      end

      it 'fetches the next job from the jobstore' do
        expect(jobstore).to receive(:fetch)
        subject.fetch
      end
    end
  end
end
