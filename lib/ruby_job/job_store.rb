# frozen_string_literal: true

module RubyJob
  class JobStore
    def enqueue(_job)
      raise NotImplementedError
    end

    def dequeue(_job)
      raise NotImplementedError
    end

    def fetch(*)
      raise NotImplementedError
    end
  end
end
