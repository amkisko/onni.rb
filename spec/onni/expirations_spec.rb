# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Expiration hygiene" do
  let(:definitions) do
    {"new_checkout" => {"everyone" => true, "expires_at" => "2000-01-01", "raise_on_expiration" => true},
     "search_v2" => {"expires_at" => "invalid"}, "future" => {"expires_at" => "2099-01-01"}}
  end

  before do
    Onni.adapter = Onni::Adapters::Memory.new
    allow(Onni.configuration).to receive(:cache).and_return(nil)
    allow(Onni::Registry).to receive(:config).and_return(definitions)
  end

  it "keeps overdue visibility and statistics while explicit verification fails" do
    Onni.ready!(:new_checkout)
    expect(Onni.visible?(:new_checkout)).to be(true)
    expect { Onni.verify_expirations! }.to raise_error(Onni::Expirations::Error, /new_checkout/)
    expect(Onni[:new_checkout].expiration_status).to eq(:overdue)
    expect(Onni[:search_v2].expiration_status).to eq(:invalid)
    expect(Onni[:future].expiration_status).to eq(:current)
  end

  it "verifies all definitions only on request and rejects invalid modes and opt-ins" do
    definitions["new_checkout"]["raise_on_expiration"] = false
    expect(Onni.verify_expirations!).to be(true)
    expect { Onni.verify_expirations!(mode: :all) }.to raise_error(Onni::Expirations::Error, /search_v2/)
    expect { Onni.verify_expirations!(mode: :unknown) }.to raise_error(ArgumentError)
    expect { Onni::Registry.validate_definition!(:bad, {"raise_on_expiration" => "yes"}) }.to raise_error(ArgumentError)
  end
end
