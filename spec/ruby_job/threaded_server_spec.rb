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
      described_class.new(num_threads: num_threads, jobstore: jobstore)
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

    describe '#initialie' do
      it 'sets the options to wait: true, wait_delay: 0.5' do
        expect(subject).to have_attributes(options: { wait: true, wait_delay: 0.5 })
      end
    end

    describe '#set' do
      it 'allows setting the :wait option' do
        subject.set(wait: false)
        expect(subject).to have_attributes(options: hash_including(wait: false))
      end

      it 'allows setting the :wait_delay option' do
        subject.set(wait_delay: 7)
        expect(subject).to have_attributes(options: hash_including(wait_delay: 7))
      end

      it 'returns self' do
        expect(subject.set(wait: false)).to be(subject)
      end
    end

    describe '#start' do
      before(:each) do
        jobs.each do |job|
          expect(job).to receive(:perform)
        end
      end

      it 'uses the :wait option' do
        subject.set(wait: false)
        expect(jobstore).to receive(:fetch).and_call_original.exactly(11).times
        Timecop.travel(now + 100)
        subject.start.join
      end

      context 'single thread' do
        it 'eventually runs all jobs' do
          subject.set(wait: false)
          Timecop.travel(now + 100)
          subject.start.join
        end
      end

      context 'multiple threads' do
        let(:num_threads) { 5 }

        it 'eventually runs all jobs' do
          subject.set(wait: false)
          Timecop.travel(now + 100)
          subject.start.join
        end
      end
    end

    describe '#halt_at' do
      it 'instructs the jobstore to halt processing jobs as of the specified time' do
        expect(jobstore).to receive(:pause_at).with(now)
        subject.halt_at(now)
      end

      it 'returns self' do
        expect(subject.halt_at(now)).to eq subject
      end
    end

    describe '#halt' do
      it 'behaves like #halt_at(Time.now)' do
        expect(subject).to receive(:halt_at).with(Time.now)
        subject.halt
      end

      it 'returns self' do
        expect(subject.halt).to eq subject
      end
    end

    describe '#resume' do
      it 'behaves like #halt_at(nil)' do
        expect(subject).to receive(:halt_at).with(nil)
        subject.resume
      end

      it 'returns self' do
        expect(subject.resume).to eq subject
      end
    end

    describe '#resume_until' do
      it 'behaves like #resume followed by #halt_at(nil)' do
        expect(subject).to receive(:resume).ordered
        expect(subject).to receive(:halt_at).with(now + 2).ordered
        subject.resume_until(now + 2)
      end

      it 'returns self' do
        expect(subject.resume_until(now)).to eq subject
      end
    end
  end
end
