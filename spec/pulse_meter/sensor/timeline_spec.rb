require 'spec_helper'

describe PulseMeter::Sensor::Timeline do
  let(:name){ :some_value_with_history }
  let(:ttl){ 100 }
  let(:raw_data_ttl){ 10 }
  let(:interval){ 5 }
  let(:reduce_delay){ 3 }
  let(:good_init_values){ {:ttl => ttl, :raw_data_ttl => raw_data_ttl, :interval => interval, :reduce_delay => reduce_delay} }
  let(:sensor){ described_class.new(name, good_init_values) }
  let(:redis){ PulseMeter.redis }

  it_should_behave_like "timeline sensor"

  describe '#new' do
    INIT_VALUE_NAMES = {
      :with_defaults => [:raw_data_ttl, :reduce_delay],
      :without_defaults => [:ttl, :interval]
    }

    shared_examples_for "error raiser" do |value_names, bad_values|
      value_names.each do |value|
        bad_values.each do |bad_value|
          it "should raise exception if a bad value #{bad_value.inspect} passed for #{value.inspect}" do
            expect{ described_class.new(name, good_init_values.merge(value => bad_value)) }.to raise_exception(ArgumentError)
          end
        end
      end
    end

    it "should initialize #ttl #raw_data_ttl #interval and #name attributes" do
      sensor.name.should == name.to_s

      sensor.ttl.should == ttl
      sensor.raw_data_ttl.should == raw_data_ttl
      sensor.interval.should == interval
    end

    it_should_behave_like "error raiser", INIT_VALUE_NAMES[:without_defaults], [:bad, -1, nil]
    it_should_behave_like "error raiser", INIT_VALUE_NAMES[:with_defaults], [:bad, -1]

    INIT_VALUE_NAMES[:with_defaults].each do |value|
      it "should not raise exception if #{value.inspect} is not defined" do
        values = good_init_values
        values.delete(value)
        expect {described_class.new(name, good_init_values)}.not_to raise_error
      end

      it "should assign default value to #{value.inspect} if it is not defined" do
        values = good_init_values
        values.delete(value)
        obj = described_class.new(name, good_init_values)
        obj.send(value).should be_kind_of(Fixnum)
      end
    end

  end

  describe "#deflate_safe" do
    class GoodSubclass < described_class
      def deflate(value)
        value.to_i
      end
    end

    class BadSubclass < described_class
      def deflate(value)
        raise "Any conversion error"
      end
    end

    let!(:good_instance) { GoodSubclass.new("good", good_init_values) }
    let!(:bad_instance) { BadSubclass.new("bad", good_init_values) }

    it "preserves nil values" do
      good_instance.deflate_safe(nil).should be_nil
    end

    it "converts value as defined in subclass" do
      good_instance.deflate_safe("10").should == 10
    end

    it "returns nil if conversion fails" do
      bad_instance.deflate_safe(:foo).should be_nil
    end
  end

end
