# frozen_string_literal: true

module RubyJob
  RSpec.describe JobProcessor do
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

    describe '#run' do
      let(:jobstore) { JobStore.new }

      subject do
        described_class.new(jobstore)
      end

      context 'order of execution' do
        before(:each) do
          job1 = Job.new(worker_class_name: 'MyWorker', args: nil)
          job2 = Job.new(worker_class_name: 'MyWorker', args: nil)
          allow(jobstore).to receive(:fetch).and_return(job1, job2, nil)
          expect(job1).to receive(:perform).ordered
          expect(job2).to receive(:perform).ordered
        end

        it "processes the jobs in the order returned by the jobstore's #fetch order" do
          subject.run
        end
      end

      context 'waiting for jobs' do
        it "uses the jobstore's #set, before calling #fetch" do
          expect(jobstore).to receive(:set).with(wait: true, wait_delay: 0.7).ordered.and_call_original
          expect(jobstore).to receive(:fetch).ordered
          subject.run(wait: true, wait_delay: 0.7)
        end
      end
    end
  end
end
