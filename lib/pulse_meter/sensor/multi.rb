module PulseMeter
  module Sensor
    class Multi < Base
      include PulseMeter::Mixins::Utils
      include Enumerable

      attr_reader :name
      attr_reader :factors
      attr_reader :sensors
      attr_reader :configuration_options

      # TODO restore in initializer

      def initialize(name, options)
        @name = name
        @factors = assert_array!(options, :factors)
        @sensors = PulseMeter::Sensor::Configuration.new
        @configuration_options = options[:configuration]
        raise ArgumentError, "configuration option missing" unless @configuration_options
      end

      def sensor(name)
        raise ArgumentError, 'need a block' unless block_given?
        sensors.sensor(name){|s| yield(s)}
      end

      def event(factors_hash, value)
        ensure_valid_factors!(factors_hash)

        each_factors_combination do |combination|
          factor_values = factor_values_for_combination(combination, factors_hash)
          get_or_create_sensor(combination, factor_values) do |s|
            s.event(value)
          end
        end
      end

      def each
        sensors.each {|s| yield(s)}
      end

      def sensor_for_factors(factor_names, factor_values)
        raise ArgumentError, 'need a block' unless block_given?
        sensor(get_sensor_name(factor_names, factor_values)){|s| yield(s)}
      end

      protected

      def is_subsensor?(sensor)
        sensor.name.start_with?(get_sensor_name([], []).to_s)
      end

      def get_or_create_sensor(factor_names, factor_values)
        raise ArgumentError, 'need a block' unless block_given?
        name = get_sensor_name(factor_names, factor_values)
        unless sensors.has_sensor?(name)
          sensors.add_sensor(name, configuration_options)
          dump!(false)
        end
        sensor(name) do |s|
          yield(s)
        end
      end

      def ensure_valid_factors!(factors_hash)
        factors.each do |factor_name|
          unless factors_hash.has_key?(factor_name)
            raise ArgumentError, "Value of factor #{factor_name} missing"
          end
        end
      end

      def each_factors_combination
        each_subset(factors) do |combination|
          yield(combination)
        end
      end

      def factor_values_for_combination(combination, factors_hash)
        combination.each_with_object([]) do |k, acc|
          acc << factors_hash[k]
        end
      end

      def get_sensor_name(factor_names, factor_values)
        sensor_name = name.to_s
        unless factor_names.empty?
          factor_names.zip(factor_values).each do |n, v|
            sensor_name << "_#{n}_#{v}"
          end
        end
        sensor_name.to_sym
      end

    end
  end
end
