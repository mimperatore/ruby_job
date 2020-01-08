# frozen_string_literal: true

module RubyJob
  class ThreadedServer
    attr_reader :options

    def initialize(num_threads:, jobstore:)
      @num_threads = num_threads
      @jobstore = jobstore
      @options = { wait: true, wait_delay: 0.5 }
    end

    def set(**options)
      @options.merge!(options)
      self
    end

    def start
      Thread.new do
        @num_threads.times.map do
          Thread.new do
            JobProcessor.new(@jobstore).run(**@options)
          end
        end.each(&:join)
      end
    end

    def halt_at(time)
      @jobstore.pause_at(time)
      self
    end

    def halt
      halt_at(Time.now)
      self
    end

    def resume
      halt_at(nil)
      self
    end

    def resume_until(time)
      resume
      halt_at(time)
      self
    end
  end
end
