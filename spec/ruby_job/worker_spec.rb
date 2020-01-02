# frozen_string_literal: true

module RubyJob
  RSpec.describe Worker do
    let(:worker_class) do
      Class.new do
        include Worker

        def perform(_, _, _); end
      end
    end

    let(:a_worker) do
      a_worker = worker_class.new
      allow(worker_class).to receive(:new).and_return(a_worker)
      a_worker
    end

    around(:each) do |example|
      Object.const_set('MyWorker', worker_class)
      example.run
      Object.send(:remove_const, 'MyWorker')
    end

    describe '.perform' do
      context 'method definition expectations' do
        let(:worker_class) do
          Class.new do
            include Worker
          end
        end

        it 'expects instances to define #perform' do
          expect { MyWorker.perform(1, 2, 3) }.to raise_error(
            NoMethodError, /undefined method `perform'/
          )
        end
      end

      context 'synchronous execution' do
        it 'returns the value returned by #perform' do
          allow(a_worker).to receive(:perform).once.with(1, 2, 3).and_return(77)
          expect(MyWorker.perform(1, 2, 3)).to eq(77)
        end

        it 'immediately calls #perform on a newly-created instance of the worker class, with the supplied args' do
          expect(a_worker).to receive(:perform).once.with(1, 2, 3)
          MyWorker.perform(1, 2, 3)
        end

        context 'on failure' do
          let(:runtime_error) { RuntimeError.new('boom') }

          let(:a_worker_that_fails) do
            a_worker = worker_class.new
            allow(worker_class).to receive(:new).and_return(a_worker)
            a_worker
          end

          before(:each) do
            allow(a_worker_that_fails).to receive(:perform).and_raise(runtime_error)
          end

          it 'does not retry by default' do
            expect(a_worker_that_fails).to receive(:perform).once
            expect { MyWorker.perform(1, 2, 3) }.to raise_error(runtime_error)
          end

          it 'keeps calling #retry? on each failure, passing the # of the '\
            'last attempt made, until #retry? returns false' do
            4.times do |i|
              expect(a_worker_that_fails).to receive(:retry?)
                .with(hash_including(attempt: i + 1)).ordered.and_return(i < 3)
            end
            expect { MyWorker.perform(1, 2, 3) }.to raise_error('boom')
          end

          it 'retries calling #perform each time #retry? returns true' do
            4.times do |i|
              expect(a_worker_that_fails).to receive(:perform).with(1, 2, 3).ordered
              expect(a_worker_that_fails).to receive(:retry?)
                .with(hash_including(attempt: i + 1)).ordered.and_return(i < 3)
            end
            expect { MyWorker.perform(1, 2, 3) }.to raise_error('boom')
          end

          it 'passes the error riased to #retry?' do
            expect(a_worker_that_fails).to receive(:retry?).with(hash_including(error: runtime_error)).and_return(false)
            expect { MyWorker.perform(1, 2, 3) }.to raise_error(runtime_error)
          end

          it 're-raises when #retry? returns false' do
            allow(a_worker_that_fails).to receive(:retry?).and_return(false)
            expect { MyWorker.perform(1, 2, 3) }.to raise_error('boom')
          end
        end
      end

      context 'asynchronous execution' do
        let(:jobstore) { double('jobstore') }

        before(:each) do
          Timecop.freeze(Time.now)
          allow(MyWorker).to receive(:jobstore).and_return(jobstore)
        end

        describe '.perform_async' do
          it 'enqueues and returns a Job for a worker with the specified arguments, that will start now' do
            job = Job.new(worker_class_name: 'MyWorker', args: [1, 2, 3], start_at: Time.now)
            expect(jobstore).to receive(:enqueue).with(job)
            expect(MyWorker.perform_async(1, 2, 3)).to eq(job)
          end
        end

        describe '.perform_at' do
          it 'enqueues and returns a Job for a worker with the specified arguments, '\
            'that will start at the specified time' do
            later = Time.now + Rational(3.5, 1000)
            job = Job.new(worker_class_name: 'MyWorker', args: [1, 2, 3], start_at: later)
            expect(jobstore).to receive(:enqueue).with(job)
            expect(MyWorker.perform_at(later, 1, 2, 3)).to eq(job)
          end
        end

        describe '.perform_in' do
          it 'enqueues and returns a Job for a worker with the specified arguments, '\
            'that will start after the specified amount of time' do
            later = Time.now + Rational(3.5, 1000)
            job = Job.new(worker_class_name: 'MyWorker', args: [1, 2, 3], start_at: later)
            expect(jobstore).to receive(:enqueue).with(job)
            expect(MyWorker.perform_in(3.5, 1, 2, 3)).to eq(job)
          end
        end
      end
    end

    describe '.jobstore=' do
      context 'on Worker' do
        it 'is defined' do
          expect(Worker).to respond_to(:jobstore=).with(1).argument
        end

        it 'stores the supplied argument' do
          jobstore = JobStore.new
          Worker.jobstore = jobstore
          expect(Worker.jobstore).to eq(jobstore)
        end

        it 'expects a JobStore object' do
          expect { Worker.jobstore = 7 }.to raise_error(ArgumentError)
        end
      end

      context 'on the including class' do
        it 'is defined' do
          expect(MyWorker).to respond_to(:jobstore=).with(1).argument
        end

        it 'stores the supplied argument' do
          jobstore = JobStore.new
          MyWorker.jobstore = jobstore
          expect(MyWorker.jobstore).to eq(jobstore)
        end

        it 'expects a JobStore object' do
          expect { MyWorker.jobstore = 7 }.to raise_error(ArgumentError)
        end
      end
    end

    describe '.jobstore' do
      context 'on Worker' do
        it 'is defined' do
          expect(Worker).to respond_to(:jobstore).with(0).arguments
        end

        it 'returns the value set by .jobstore=' do
          jobstore = JobStore.new
          Worker.jobstore = jobstore
          expect(Worker.jobstore).to eq(jobstore)
        end
      end

      context 'on the including class' do
        it 'is defined' do
          expect(MyWorker).to respond_to(:jobstore).with(0).arguments
        end

        it 'returns the value set by .jobstore=' do
          jobstore = JobStore.new
          MyWorker.jobstore = jobstore
          expect(MyWorker.jobstore).to eq(jobstore)
        end

        it "returns the value set by Worker.jobstore=, if the including class didn't set it explicitly" do
          jobstore = JobStore.new
          Worker.jobstore = jobstore
          expect(MyWorker.jobstore).to eq(jobstore)
        end
      end
    end
  end
end
