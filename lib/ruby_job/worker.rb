# frozen_string_literal: true

module RubyJob
  module Worker
    def self.included(base)
      base.extend(ClassMethods)
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
      def perform(*args)
        worker = new
        worker.send(:do_perform, *args)
      end

      def perform_async(*args)
        Job.new(class_name: name, args: args)
      end

      def perform_at(at, *args)
        Job.new(class_name: name, args: args, start_at: at)
      end

      def perform_in(in_ms, *args)
        at = Time.now + Rational(in_ms, 1000)
        Job.new(class_name: name, args: args, start_at: at)
      end
    end
  end
end
