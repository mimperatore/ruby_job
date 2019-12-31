# frozen_string_literal: true

module RubyJob
  class InMemoryJobStore < JobStore
    attr_reader :pause_starting_at

    def initialize
      @semaphore = Mutex.new
      @semaphore.synchronize { @jobs_to_drop = {} }
    end

    def enqueue(job)
      @semaphore.synchronize { queue.push(job) }
    end

    def dequeue(job)
      @semaphore.synchronize { @jobs_to_drop[job.to_json] = job }
    end

    def pause_at(time)
      @pause_starting_at = time
    end

    def fetch(wait: false, delay: 0.5)
      wait ? fetch_next_or_wait(delay) : fetch_next
    end

    def size
      to_a.size
    end

    def to_a
      @semaphore.synchronize { queue.to_a - @jobs_to_drop.values }
    end

    private

    def queue
      @queue ||= PQueue.new do |a, b|
        b.start_at <=> a.start_at
      end
    end

    def paused_before?(time)
      @pause_starting_at && @pause_starting_at <= time
    end

    def drop_dequeued
      queue.pop while (top = queue.top) && @jobs_to_drop.delete(top.to_json)
    end

    def fetch_next
      @semaphore.synchronize do
        drop_dequeued
        queue.pop if (top = queue.top) && top.start_at <= [Time.now, @pause_starting_at].compact.min
      end
    end

    def fetch_next_or_wait(delay)
      job = nil
      loop do
        job = fetch_next
        break if job || paused_before?(Time.now)

        sleep(delay)
      end
      job
    end
  end
end
