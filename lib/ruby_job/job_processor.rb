# frozen_string_literal: true

module RubyJob
  class JobProcessor
    def initialize(jobstore)
      @jobstore = jobstore
    end

    def run(wait: false)
      loop do
        job = @jobstore.fetch(wait: wait)
        job ? job.perform : break
      end
    end
  end
end
