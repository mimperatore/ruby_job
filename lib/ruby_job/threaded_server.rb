# frozen_string_literal: true

module RubyJob
  class ThreadedServer
    def initialize(num_threads, jobstore)
      @num_threads = num_threads
      @jobstore = jobstore
    end

    def start(wait: true)
      Thread.new do
        @num_threads.times.map do
          Thread.new do
            JobProcessor.new(@jobstore).run(wait: wait)
          end
        end.each(&:join)
      end
    end

    def stop_at(time)
      @jobstore.pause_at(time)
    end

    def stop
      stop_at(Time.now)
    end
  end
end
