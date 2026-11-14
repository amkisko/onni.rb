# frozen_string_literal: true

module Onni
  module Admin
    module GraphQL
      module Types
        class Base < ::GraphQL::Schema::Object
          def self.field(*arguments, **options, &block)
            super(*arguments, camelize: false, **options, &block)
          end
        end

        class Power < ::GraphQL::Schema::Enum
          graphql_name "OnniPower"
          %i[pending ready parked].each { |state| value state.to_s.upcase, value: state }
        end

        class Audience < Base
          graphql_name "OnniAudience"
          field :everyone, Boolean
          field :groups, [String]
          field :actors, [String]
          field :excluded_groups, [String]
          field :excluded_actors, [String]
          field :level, Integer
        end

        class Variant < Base
          graphql_name "OnniVariant"
          field :name, String, null: false
          field :weight, ::GraphQL::Types::BigInt, null: false
        end

        class Signal < Base
          graphql_name "OnniSignal"
          field :key, String, null: false
          field :level, Inputs::SignedInteger, null: false
          field :threshold, Inputs::SignedInteger
        end

        class Experiment < Base
          graphql_name "OnniDeliveryExperiment"
          field :name, String, null: false
          field :filters, Audience, null: false
        end

        class StatsSettings < Base
          graphql_name "OnniStatsSettings"
          field :enabled, Boolean, null: false
          field :sample_rate, Float, null: false
        end

        class StatBucket < Base
          graphql_name "OnniStatBucket"
          field :period_start, ::GraphQL::Types::ISO8601DateTime, null: false
          field :shown_count, ::GraphQL::Types::BigInt, null: false
          field :skip_count, ::GraphQL::Types::BigInt, null: false
        end

        class Feature < Base
          graphql_name "OnniFeature"
          field :name, String, null: false
          field :type, String
          field :conditions, [String], null: false
          field :raise_on_expiration, Boolean, null: false
          field :description, String
          field :expires_at, String
          field :expiration_status, String, null: false
          field :power, Power, null: false
          field :filters, Audience, null: false
          field :variants, [Variant], null: false
          field :signals, [Signal], null: false
          field :experiments, [Experiment], null: false
          field :stats, StatsSettings, null: false
          field :statistics, [StatBucket], null: false do
            argument :hours, Integer, required: false, default_value: 24
          end

          def statistics(hours:)
            raise ::GraphQL::ExecutionError, "Hours must be in 1..720" unless hours.between?(1, 720)

            Onni::Stats.for(object.fetch(:name), from: Time.now.utc - hours * 3600, to: Time.now.utc)
          end
        end

        class FeaturePage < Base
          graphql_name "OnniFeaturePage"
          field :items, [Feature], null: false
          field :next_cursor, String
          field :total_count, Integer, null: false
        end

        class Queries < Base
          graphql_name "OnniQueries"
          field_class Field
          field :feature, Feature do
            argument :name, String, required: true
          end
          field :features, FeaturePage, null: false,
            complexity: ->(_, arguments, child) { arguments.fetch(:first, 25).clamp(1, 100) * child + 1 } do
            argument :first, Integer, required: false, default_value: 25
            argument :after, String, required: false
          end

          def self.visible?(context)
            super && Access.allowed?(context, :read)
          end

          def feature(name:)
            Snapshot.find(name)
          end

          def features(first:, after: nil)
            Snapshot.page(first: first, after: after)
          end
        end
      end
    end
  end
end
