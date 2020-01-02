# frozen_string_literal: true

require 'securerandom'
require 'json'
require 'time'
require 'bigdecimal/util'

module RubyJob
  class Job < FibonacciHeap::Node
    attr_reader :worker_class_name, :args, :start_at, :jobstore, :uuid

    def initialize(
      worker_class_name:,
      args:,
      start_at: Time.now,
      uuid: nil,
      jobstore: Job.send(:default_jobstore, worker_class_name)
    )
      @worker_class_name = worker_class_name
      @args = args
      @start_at = Time.at(start_at.to_f.round(3))
      @uuid_id = uuid
      @jobstore = jobstore
    end

    def perform
      worker_class.perform(*@args)
    end

    def ==(other)
      return false unless other.is_a? Job

      @start_at == other.start_at &&
        @uuid == other.uuid &&
        @args == other.args &&
        @worker_class_name == other.worker_class_name
    end

    def to_h
      {
        'json_class' => self.class.name,
        'data' => {
          'worker_class_name' => @worker_class_name,
          'args_json' => JSON.dump(@args),
          'start_at' => @start_at.iso8601(9),
          'uuid' => @uuid
        }
      }
    end

    def to_json(*args)
      to_h.to_json(*args)
    end

    def self.json_create(hash)
      worker_class_name = hash['data']['worker_class_name']
      args = JSON.parse(hash['data']['args_json'])
      start_at = Time.iso8601(hash['data']['start_at'])
      uuid = hash['data']['uuid']
      new(worker_class_name: worker_class_name, args: args, start_at: start_at, uuid: uuid)
    end

    def enqueue
      raise 'job has already been enqueued' if @uuid

      @uuid = @jobstore.next_uuid
      @jobstore.enqueue(self)
      self
    end

    def dequeue
      raise 'job was not queued' unless @uuid

      @jobstore.dequeue(self)
      @uuid = nil
      self
    end

    def fetch
      @jobstore.fetch
    end

    private

    def worker_class
      @worker_class ||= @worker_class_name.split('::').reduce(Module, :const_get)
    end

    class << self
      private

      def default_jobstore(worker_class_name)
        worker_class = worker_class_name.split('::').reduce(Module, :const_get)
        class_with_jobstore_method = worker_class.respond_to?(:jobstore) ? worker_class : Worker
        class_with_jobstore_method.jobstore
      end
    end
  end
end
