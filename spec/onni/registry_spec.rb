# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tmpdir"

RSpec.describe Onni::Registry do
  around do |example|
    previous_path = Onni.configuration.features_path
    example.run
  ensure
    Onni.configuration.features_path = previous_path
    described_class.reload!
  end

  it "loads YAML keys and parses expires_at once" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "features.yml")
      File.write(path, <<~YAML)
        search_v2:
          description: New search
          expires_at: "2099-06-01T00:00:00Z"
      YAML
      Onni.configuration.features_path = path
      described_class.reload!

      expect(described_class.known?(:search_v2)).to be(true)
      definition = described_class.definition(:search_v2)
      expect(definition["description"]).to eq("New search")
      expect(definition["expires_at_time"]).to eq(Time.parse("2099-06-01T00:00:00Z").utc)
    end
  end

  it "raises KeyError for an unknown definition" do
    Onni.configuration.features_path = File.join(Dir.mktmpdir, "missing.yml")
    described_class.reload!

    expect { described_class.require_definition!(:missing) }.to raise_error(KeyError, /missing/)
  end

  it "leaves expires_at_time unset when the deadline cannot be parsed" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "features.yml")
      File.write(path, <<~YAML)
        broken_expiry:
          expires_at: "not-a-date"
      YAML
      Onni.configuration.features_path = path
      described_class.reload!

      definition = described_class.definition(:broken_expiry)
      expect(definition["expires_at"]).to eq("not-a-date")
      expect(definition).not_to have_key("expires_at_time")
    end
  end

  it "does not discover an ambient Rails path when features_path is unset" do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "config"))
      File.write(File.join(dir, "config", "features.yml"), "from_rails:\n  description: Via root\n")
      root = Pathname.new(dir)
      rails = Module.new
      rails.define_singleton_method(:root) { root }
      stub_const("Rails", rails)

      Onni.configuration.features_path = nil
      described_class.reload!

      expect(described_class.known?(:from_rails)).to be(false)
      expect(described_class.definition(:from_rails)).to be_nil
    end
  end

  it "loads independent audience defaults without assigning an exclusive type" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, "features.yml")
      File.write(path, YAML.dump(
        "basic" => {}, "global" => {"everyone" => true},
        "rollout" => {"level" => 30},
        "audience" => {"groups" => ["beta_testers"]},
        "selected" => {"actors" => ["User;1"]},
        "experiment" => {"type" => "experiment", "everyone" => true, "variants" => {"control" => 100}}
      ))
      Onni.configuration.features_path = path
      described_class.reload!
      expect(described_class.definition(:basic)["type"]).to be_nil
      expect(described_class.definition(:global)["everyone"]).to be(true)
      expect(described_class.definition(:rollout)["level"]).to eq(30)
      expect(described_class.definition(:audience)["groups"]).to eq(["beta_testers"])
      expect(described_class.definition(:selected)["actors"]).to eq(["User;1"])
      expect(described_class.definition(:experiment)["type"]).to eq("experiment")
    end
  end

  [nil, {"stats" => false}, {"stats" => {"enabled" => nil}}, {"stats" => {"sample_rate" => "0.5"}},
    {"stats" => {"unknown" => true}}, *%w[unknown boolean percentage group actors].map { |type| {"type" => type} },
    {"everyone" => "true"}, {"everyone" => nil}, {"excluded_groups" => "staff"}, {"level" => 101},
    {"level" => "30"}, {"groups" => "staff"},
    {"actors" => [nil]}, {"conditions" => [1]},
    {"type" => "experiment", "everyone" => true, "variants" => {"control" => -1}},
    {"type" => "experiment", "everyone" => true, "variants" => {"control" => 0}}].each do |definition|
    it "rejects malformed YAML definition #{definition.inspect}" do
      Dir.mktmpdir do |directory|
        path = File.join(directory, "features.yml")
        File.write(path, YAML.dump("demo" => definition))
        Onni.configuration.features_path = path
        expect { described_class.reload! }.to raise_error(ArgumentError)
      ensure
        Onni.configuration.features_path = nil
      end
    end
  end
end
