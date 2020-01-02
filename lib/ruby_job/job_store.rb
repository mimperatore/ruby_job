# frozen_string_literal: true

module RubyJob
  class JobStore
    def enqueue(_job)
      raise NotImplementedError
    end

    def dequeue(_job)
      raise NotImplementedError
    end

    def pause_at(_time)
      raise NotImplementedError
    end

    def fetch(*)
      raise NotImplementedError
    end

    def size
      raise NotImplementedError
    end

    def next_uuid
      raise NotImplementedError
    end
  end
end
