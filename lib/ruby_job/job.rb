# frozen_string_literal: true

module RubyJob
  class Job
    def initialize(class_name:, args:, start_at: Time.now)
      @class_name = class_name
      @args = args
      @start_at = start_at
    end

    def ==(other)
      to_json == other.to_json
    end

    def to_h
      {
        'json_class' => self.class.name,
        'data' => {
          'class_name' => @class_name,
          'args_json' => JSON.dump(@args),
          'start_at' => @start_at.iso8601(9)
        }
      }
    end

    def to_json(*args)
      to_h.to_json(*args)
    end

    def self.json_create(hash)
      class_name = hash['data']['class_name']
      args = JSON.parse(hash['data']['args_json'])
      start_at = Time.iso8601(hash['data']['start_at'])
      new(class_name: class_name, args: args, start_at: start_at)
    end
  end
end
