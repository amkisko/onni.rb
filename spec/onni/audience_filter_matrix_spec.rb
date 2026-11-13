# frozen_string_literal: true

require "spec_helper"
require_relative "../support/audience_filter_cases"

RSpec.describe "Audience filter contract matrix" do
  PROFILES = {
    "ordinary flag" => [{"variants" => {"treatment" => 100}}, nil],
    "experiment with weights" => [{"type" => "experiment", "variants" => {"treatment" => 100}}, :treatment],
    "experiment without weights" => [{"type" => "experiment", "variants" => {}}, nil]
  }.freeze

  let(:definitions) { {} }
  let(:actors) do
    {anonymous: nil, beta: Struct.new(:feature_actor_id).new("User;29"),
     staff: Struct.new(:feature_actor_id).new("User;5")}
  end
  let(:defaults) do
    {"everyone" => true, "groups" => ["beta_testers"], "actors" => ["User;29"],
     "excluded_groups" => ["beta_testers"], "excluded_actors" => ["User;29"], "level" => 49}
  end

  around do |example|
    previous_cache = Onni.configuration.cache
    example.run
  ensure
    Onni.configuration.cache = previous_cache
    Onni.reset_request!
    Onni::Group.clear!
  end

  before do
    Onni.configuration.cache = nil
    Onni.adapter = Onni::Adapters::Memory.new
    Onni.reset_request!
    allow(Onni::Registry).to receive(:config).and_return(definitions)
    Onni.register_group(:beta_testers) { |actor, _| actor.feature_actor_id == "User;29" }
    Onni.register_group(:staff) { |actor, _| actor.feature_actor_id == "User;5" }
  end

  def define_feature(filters, metadata)
    definition = filters.merge(metadata)
    Onni::Registry.validate_definition!("new_checkout", definition)
    definitions["new_checkout"] = definition
  end

  def outcomes
    actors.values.map do |actor|
      [Onni.visible?(:new_checkout, actor, record_stats: false),
        Onni.variant(:new_checkout, actor, record_stats: false)]
    end
  end

  def expected_outcomes(audience, assignment)
    actors.keys.map do |name|
      visible = audience.include?(name)
      [visible, (visible && name != :anonymous) ? assignment : nil]
    end
  end

  def state
    flag = Onni[:new_checkout]
    [flag.power_state, flag.filters, flag.variants, outcomes]
  end

  def expected_state(power, row, metadata, assignment)
    audience = (power == :ready) ? row.audience : []
    [power, row.filters.compact, metadata.fetch("variants"), expected_outcomes(audience, assignment)]
  end

  PROFILES.each do |kind, (metadata, assignment)|
    %i[defaults runtime].each do |source|
      %i[pending ready parked].each do |power|
        it "checks #{AudienceFilterCases::ROWS.size} combinations for #{kind} from #{source} while #{power}" do
          AudienceFilterCases::ROWS.each do |row|
            Onni.adapter.clear!
            Onni.reset_request!
            runtime_weights = source == :runtime && metadata["type"] == "experiment"
            stored_metadata = runtime_weights ? metadata.merge("variants" => {"control" => 100}) : metadata
            define_feature((source == :defaults) ? row.filters.compact : defaults, stored_metadata)
            Onni.ready!(:new_checkout) if power == :ready
            Onni.park!(:new_checkout) if power == :parked
            Onni.variants!(:new_checkout, metadata["variants"]) if runtime_weights
            Onni.filters!(:new_checkout, **row.filters) if source == :runtime
            expect(state).to eq(expected_state(power, row, metadata, assignment)),
              -> { "#{kind}/#{source}/#{power}: #{row.description}" }
            if power == :ready
              Onni.park!(:new_checkout)
              expect(state).to eq(expected_state(:parked, row, metadata, assignment)),
                -> { "#{kind}/#{source}/park: #{row.description}" }
            end
            unless power == :pending
              Onni.ready!(:new_checkout)
              expect(state).to eq(expected_state(:ready, row, metadata, assignment)),
                -> { "#{kind}/#{source}/resume: #{row.description}" }
            end
          end
        end
      end
    end

    it "checks inherited, replaced, and removed defaults for #{kind} in partial runtime updates" do
      define_feature(defaults, metadata)
      AudienceFilterCases.precedence_rows.each do |row|
        Onni.adapter.clear!
        Onni.reset_request!
        Onni.ready!(:new_checkout)
        row.filters.each { |key, value| Onni.filters!(:new_checkout, **{key => value}) }
        expected = [:ready, defaults.merge(row.filters).compact, metadata.fetch("variants"), expected_outcomes(row.audience, assignment)]
        expect(state).to eq(expected), -> { row.description }
      end
    end

    %i[pending ready parked].each do |power|
      it "checks all filter update orders for #{kind} while #{power}" do
        desired = {"everyone" => false, "groups" => ["beta_testers"], "actors" => ["User;29"],
                   "excluded_groups" => ["staff"], "excluded_actors" => nil, "level" => 50}
        define_feature(defaults, metadata)
        desired.keys.permutation.each do |order|
          Onni.adapter.clear!
          Onni.reset_request!
          Onni.ready!(:new_checkout) if power == :ready
          Onni.park!(:new_checkout) if power == :parked
          order.each { |key| Onni.filters!(:new_checkout, **{key => desired[key]}) }
          audience = (power == :ready) ? [:beta] : []
          expected = [power, desired.compact, metadata.fetch("variants"), expected_outcomes(audience, assignment)]
          expect(state).to eq(expected), -> { order.inspect }
        end
      end
    end

    {"conditions" => [{"conditions" => ["beta_testers"]}, %i[anonymous beta]],
     "expired" => [{"expires_at" => "2000-01-01"}, []],
     "invalid expiry" => [{"expires_at" => "invalid"}, []]}.each do |restriction, (fields, allowed)|
      it "applies #{restriction} to every filter-presence combination for #{kind}" do
        AudienceFilterCases.presence_rows.each do |row|
          Onni.adapter.clear!
          Onni.reset_request!
          define_feature(row.filters.compact.merge(fields), metadata)
          Onni.ready!(:new_checkout)
          expect(outcomes).to eq(expected_outcomes(row.audience & allowed, assignment)), -> { row.description }
        end
      end
    end
  end
end
