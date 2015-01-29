require 'json'

module PulseMeter
  module Sensor
    module Timelined
      # Counts multiple types of events per interval.
      # Good replacement for multiple counters to be visualized together
      class HashedCounter < Timeline
        def aggregate_event(key, data)
          data.each_pair do |k, v|
            command_aggregator.hincrby(key, k, v)
          end
        end

        def summarize(key)
          if PulseMeter.debug?
            PulseMeter.error "summarize key #{key}, raw value: #{redis.hgetall(key).inspect}"
          end
          redis.
            hgetall(key).
            inject({}) {|h, (k, v)| h[k] = v.to_i; h}.
            to_json
        end

        private

        def deflate(value)
          JSON.parse(value)
        end
      end
    end
  end
end
