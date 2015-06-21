require 'spec_helper'

describe PulseMeter::UDPServer do
  let(:host){'127.0.0.1'}
  let(:port){33333}
  let(:udp_sock){double(:socket)}
  let(:redis){PulseMeter.redis}
  before do
    expect(UDPSocket).to receive(:new).and_return(udp_sock)
    expect(udp_sock).to receive(:bind).with(host, port).and_return(nil)
    expect(udp_sock).to receive("do_not_reverse_lookup=").with(true).and_return(nil)
    @server = described_class.new(host, port)
  end

  describe "#start" do
    let(:data){
      [
        ["set", "xxxx", "zzzz"],
        ["set", "yyyy", "zzzz"]
      ].to_json
    }
    it "processes proper incoming commands" do
      expect(udp_sock).to receive(:recvfrom).with(described_class::MAX_PACKET).and_return(data)
      @server.start(1)
      expect(redis.get("xxxx")).to eq("zzzz")
      expect(redis.get("yyyy")).to eq("zzzz")
    end

    it "suppresses JSON errors" do
      expect(udp_sock).to receive(:recvfrom).with(described_class::MAX_PACKET).and_return("xxx")
      expect{ @server.start(1) }.not_to raise_exception
    end
  end

end

