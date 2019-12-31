# frozen_string_literal: true

module RubyJob
  class JobProcessor
    def initialize(jobstore)
      @jobstore = jobstore
    end

    def run(**options)
      loop do
        job = @jobstore.fetch(**options)
        job ? job.perform : break
      end
    end
  end
end
