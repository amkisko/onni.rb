# frozen_string_literal: true

require "spec_helper"

RSpec.describe Onni::Configuration do
  subject(:configuration) { described_class.new }

  it "expresses retention as elapsed seconds and leaves integrations unset" do
    expect(configuration.stats_retention).to eq(7_776_000)
    expect(configuration.stats_retention.class).to eq(Integer)
    expect(configuration.instrumenter).to be_nil
    expect(configuration.logger).to be_nil
    expect(configuration.features_path).to eq("config/features.yml")
  end

  it "accepts seconds or an explicitly unset retention" do
    configuration.stats_retention = 3_600
    expect(configuration.stats_retention).to eq(3_600)
    configuration.stats_retention = nil
    expect(configuration.stats_retention).to be_nil
  end

  it "rejects invalid retention values without replacing the configured interval" do
    [-1, 1.5, "3600", Object.new, 1.day].each do |value|
      expect { configuration.stats_retention = value }.to raise_error(ArgumentError)
      expect(configuration.stats_retention).to eq(7_776_000)
    end
  end
end
