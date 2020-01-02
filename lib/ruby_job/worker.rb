# frozen_string_literal: true

module RubyJob
  module Worker
    class << self
      def included(base)
        base.extend(ClassMethods)
      end

      attr_reader :jobstore

      def jobstore=(jobstore)
        raise ArgumentError, 'argument provided is not a JobStore' unless jobstore.is_a?(JobStore)

        @jobstore = jobstore
      end
    end

    def retry?(*)
      false
    end

    private

    def do_perform(*args)
      @attempt ||= 1
      perform(*args)
    rescue StandardError => e
      raise unless retry?(attempt: @attempt, error: e)

      @attempt += 1
      retry
    end

    module ClassMethods
      def jobstore=(jobstore)
        raise ArgumentError, 'argument provided is not a JobStore' unless jobstore.is_a?(JobStore)

        @jobstore = jobstore
      end

      def jobstore
        @jobstore || Worker.jobstore
      end

      def perform(*args)
        worker = new
        worker.send(:do_perform, *args)
      end

      def perform_async(*args)
        Job.new(worker_class_name: name, args: args).enqueue
      end

      def perform_at(at, *args)
        Job.new(worker_class_name: name, args: args, start_at: at).enqueue
      end

      def perform_in(in_ms, *args)
        at = Time.now + in_ms.to_f / 1000
        Job.new(worker_class_name: name, args: args, start_at: at).enqueue
      end
    end
  end
end
