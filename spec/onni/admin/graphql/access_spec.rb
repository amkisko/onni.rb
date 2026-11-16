# frozen_string_literal: true

require "rails_helper"

RSpec.describe Onni::Admin::GraphQL::Access do
  describe ".map_capabilities" do
    it "maps host scopes onto onni capabilities and keeps native onni scopes" do
      expect(described_class.map_capabilities(%w[desk:read], read: %w[desk:read], write: %w[desk:write]))
        .to eq(["onni:read"])
      expect(described_class.map_capabilities(%w[desk:write], read: %w[desk:read], write: %w[desk:write]))
        .to eq(["onni:write"])
      expect(described_class.map_capabilities(%w[desk:read desk:write], read: %w[desk:read], write: %w[desk:write]))
        .to eq(%w[onni:read onni:write])
      expect(described_class.map_capabilities(%w[onni:read other], read: %w[desk:read], write: %w[desk:write]))
        .to eq(["onni:read"])
      expect(described_class.map_capabilities(["", nil, "  "], read: %w[desk:read], write: %w[desk:write]))
        .to eq([])
    end
  end
end
