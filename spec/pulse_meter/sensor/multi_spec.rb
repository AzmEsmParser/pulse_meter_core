require 'spec_helper'

describe PulseMeter::Sensor::Multi do
  let(:name){ :foo }
  let(:annotation) { "Multi sensor" }
  let(:type) {'counter'}
  let(:factors) {[:f1, :f2]}
  let(:configuration) {
    {
      sensor_type: type,
      args: {
        annotation: annotation
      }
    }
  }
  let(:init_values) { { factors: factors, configuration: configuration } }
  let!(:sensor) { described_class.new(name, init_values) }
  let!(:redis){ PulseMeter.redis }

  describe '#initialize' do
    context "when factors are not corretly passed" do
      it "raises ArgumentError" do
        expect {described_class.new(name, {factors: :not_array, configuration: configuration})}.to raise_exception(ArgumentError)
        expect {described_class.new(name, {configuration: configuration})}.to raise_exception(ArgumentError)
      end
    end

    context "when configuration missing" do
      it "raises ArgumentError" do
        expect {described_class.new(name, {factors: factors})}.to raise_exception(ArgumentError)
      end
    end
  end

  describe "#factors" do
    it "returns factors passed to constructor" do
      expect(sensor.factors).to eq(factors)
    end
  end

  describe "#configuration_options" do
    it "returns configuration option passed to constructor" do
      expect(sensor.configuration_options).to eq(configuration)
    end
  end

  describe "#sensors" do
    it "returns PulseMeter::Sensor::Configuration instance" do
      expect(sensor.sensors).to be_instance_of(PulseMeter::Sensor::Configuration)
    end
  end

  describe "#event" do

    it "raises ArgumentError unless all factors' values given" do
      expect {sensor.event({f1: :v1}, 1)}.to raise_exception(ArgumentError)
    end


    context "when sensors must be created" do
      let(:factor_values) { {f1: :v1, f2: :v2} }

      it "implicitly creates them" do
        expect {sensor.event(factor_values, 1)}.to change{sensor.sensors.to_a.count}
      end

      it "assigns names based on factors' names and values" do
        sensor.event(factor_values, 1)
        names = sensor.sensors.to_a.map(&:name)
        expect(names.sort).to eq([
          "#{name}",
          "#{name}_f1_v1",
          "#{name}_f2_v2",
          "#{name}_f1_v1_f2_v2"
        ].sort)
      end

      it "creates sensors of given type with configuration options passed" do
        sensor.event(factor_values, 1)
        sensor.sensors.each do |s|
          expect(s).to be_instance_of(PulseMeter::Sensor::Counter)
          expect(s.annotation).to eq(annotation)
        end
      end
    end

    it "sends event to all combinations of factors and values" do
      sensor.event({f1: :f1v1, f2: :f2v1}, 1)
      sensor.event({f1: :f1v2, f2: :f2v1}, 2)
      [
        ["#{name}", 3],
        ["#{name}_f1_f1v1", 1],
        ["#{name}_f1_f1v2", 2],
        ["#{name}_f2_f2v1", 3],
        ["#{name}_f1_f1v1_f2_f2v1", 1],
        ["#{name}_f1_f1v2_f2_f2v1", 2]
      ].each do |sensor_name, sum|
        sensor.sensor(sensor_name) { |s|
          expect(s.value).to eq(sum)
        }
      end
    end
  end

  describe "#each" do
    it "when used by Enumerable it lists all ever created subsensors of multisensor" do
      sensor.event({f1: :f1v1, f2: :f2v1}, 1)
      restored_sensor = PulseMeter::Sensor::Base.restore(name)

      expect(restored_sensor.to_a.map(&:name).sort).to eq([
        "#{name}",
        "#{name}_f1_f1v1",
        "#{name}_f2_f2v1",
        "#{name}_f1_f1v1_f2_f2v1",
      ].sort)
    end
  end

  describe "#sensor_for_factors" do
    context "when sensor has already been created" do
      it "yields block with sensor for given combination of factors and their values" do
        sensor.event({f1: :f1v1, f2: :f2v1}, 1)
        sensor.sensor_for_factors([:f1, :f2], [:f1v1, :f2v1]){|s| expect(s.name).to eq("#{name}_f1_f1v1_f2_f2v1")}
        sensor.sensor_for_factors([:f1], [:f1v1]){|s| expect(s.name).to eq("#{name}_f1_f1v1")}
      end
    end

    context "when such a sensor was not created" do
      it "does not yields block" do
        yielded = false
        sensor.sensor_for_factors([:foo], [:bar]){ yielded = true }
        expect(yielded).not_to be
      end
    end
  end

end
