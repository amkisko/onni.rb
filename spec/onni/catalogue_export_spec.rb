# frozen_string_literal: true

require "spec_helper"
require "yaml"
require "csv"
require "stringio"
require "rake"

RSpec.describe "Catalogue export" do
  let(:definition) do
    {"description" => "Checkout, safely\nwith \"quoted\" descriptions", "expires_at" => "2099-01-01", "expires_at_time" => Time.utc(2099),
     "signals" => {"exception" => {"threshold" => 3}}}
  end

  before do
    Onni.adapter = Onni::Adapters::Memory.new
    allow(Onni::Registry).to receive(:config).and_return("new_checkout" => definition)
    allow(Onni::Delivery).to receive(:entries).and_return({})
  end

  it "exports equivalent YAML, JSON and CSV with declared experiments and optional runtime" do
    Class.new(Onni::Delivery) do
      feature :new_checkout
      parked { :legacy }
      experiment(:new_flow, everyone: true) { :new }
    end
    Onni.ready!(:new_checkout)
    Onni.observe!(:new_checkout, :exception)
    Onni.experiment_filters!(:new_checkout, :new_flow, level: 10)
    json = JSON.parse(Onni.export_catalogue(format: :json, runtime: true))
    yaml = YAML.safe_load(Onni.export_catalogue(format: "yaml", runtime: true))
    csv = CSV.parse(Onni.export_catalogue(format: :csv, runtime: true), headers: true)
    expect(yaml).to eq(json)
    expect(json.first.fetch("experiments")).to eq("new_flow" => {"everyone" => true})
    expect(json.first.dig("runtime", "signal_levels", "exception")).to eq(1)
    expect(json.first.dig("runtime", "experiments", "new_flow", "level")).to eq(10)
    expect(json.first.fetch("definition")).not_to have_key("expires_at_time")
    expect(JSON.parse(csv.first.fetch("definition"))).to eq(json.first.except("runtime"))
    expect(JSON.parse(csv.first.fetch("runtime"))).to eq(json.first.fetch("runtime"))
    expect(JSON.parse(Onni.export_catalogue(format: :json)).first).not_to have_key("runtime")
  end

  it "supports IO and rejects unsupported formats before writing" do
    io = StringIO.new
    Onni.export_catalogue(format: :json, io: io)
    expect(JSON.parse(io.string).first.fetch("name")).to eq("new_checkout")
    expect { Onni.export_catalogue(format: :xml, io: io) }.to raise_error(ArgumentError)
    expect(JSON.parse(io.string).size).to eq(1)
  end

  it "packages generic and fixed-format rake tasks and honors OUTPUT" do
    require "tempfile"
    previous_rake = Rake.application
    Rake.application = Rake::Application.new
    load File.expand_path("../../lib/onni/tasks.rb", __dir__)
    Tempfile.create(["catalogue", ".json"]) do |file|
      original = ENV.to_h.slice("OUTPUT", "FORMAT")
      ENV["OUTPUT"] = file.path
      ENV["FORMAT"] = "invalid"
      Rake::Task["onni:export_json"].invoke
      expect(JSON.parse(File.read(file.path)).first.fetch("name")).to eq("new_checkout")
      ENV["FORMAT"] = "csv"
      Rake::Task["onni:export"].invoke
      expect(CSV.read(file.path, headers: true).first.fetch("name")).to eq("new_checkout")
    ensure
      %w[OUTPUT FORMAT].each { |key| original.key?(key) ? ENV[key] = original[key] : ENV.delete(key) }
    end
  ensure
    Rake.application = previous_rake
  end
end
