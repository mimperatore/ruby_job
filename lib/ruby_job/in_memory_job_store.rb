# frozen_string_literal: true

require 'forwardable'
require 'fibonacci_heap'
require 'digest/sha1'

module RubyJob
  class InMemoryJobStore < JobStore
    attr_reader :pause_starting_at

    def initialize
      super
      @semaphore = Mutex.new
      @next_uuid = 0
      @pause_starting_at = nil
    end

    def enqueue(job)
      raise 'job does not have an assigned uuid' unless job.uuid

      @semaphore.synchronize { queue.push(job) }
    end

    def dequeue(job)
      @semaphore.synchronize { queue.delete(job) }
    end

    def pause_at(time)
      @pause_starting_at = time
    end

    def fetch
      @options[:wait] ? fetch_next_or_wait : fetch_next
    end

    def size
      queue.size
    end

    def next_uuid
      @semaphore.synchronize { @next_uuid += 1 }
    end

    private

    def queue
      @queue ||= JobPriorityQueue.new
    end

    def paused_before?(time)
      @pause_starting_at && @pause_starting_at <= time
    end

    def fetch_next
      @semaphore.synchronize do
        queue.pop if (top = queue.top) && top.start_at <= [Time.now, @pause_starting_at].compact.min
      end
    end

    def fetch_next_or_wait
      job = nil
      loop do
        job = fetch_next
        break if job || (paused_before?(Time.now) && !@options[:wait])

        sleep(@options[:wait_delay])
      end
      job
    end

    class JobPriorityQueue
      extend Forwardable

      def_delegators :@pqueue, :size

      def initialize
        @pqueue = FibonacciHeap::Heap.new
      end

      def push(job)
        @pqueue.insert(job, key_for(job))
      end

      def pop
        @pqueue.pop
      end

      def top
        @pqueue.min
      end

      def delete(job)
        @pqueue.delete(job)
      end

      private

      def key_for(job)
        job.start_at.to_f.round(3) + job.uuid.to_f / 1_000
      end
    end
  end
end
