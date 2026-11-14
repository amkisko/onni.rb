# frozen_string_literal: true

module Onni
  module Admin
    module GraphQL
      module Inputs
        class SignedInteger < ::GraphQL::Schema::Scalar
          graphql_name "OnniSignedInteger"
          description "Signed 64-bit integer; use a decimal string to preserve precision."

          def self.coerce_input(value, _context)
            return if value.nil?
            if value.is_a?(String)
              raise ArgumentError unless value.match?(/\A[+-]?\d{1,19}\z/)

              value = Integer(value, 10)
            end
            SignalPolicy.integer!(value)
          rescue ArgumentError
            raise ::GraphQL::CoercionError, "Use a signed 64-bit integer"
          end

          def self.coerce_result(value, _context)
            value.to_s
          end
        end

        class Base < ::GraphQL::Schema::InputObject
          def self.argument(*arguments, **options, &block)
            super(*arguments, camelize: false, **options, &block)
          end
        end

        class Audience < Base
          graphql_name "OnniAudienceInput"
          description "Set clauses match together; null removes a clause."
          argument :everyone, Boolean, required: false
          argument :groups, [String], required: false
          argument :actors, [String], required: false
          argument :excluded_groups, [String], required: false
          argument :excluded_actors, [String], required: false
          argument :level, Integer, required: false
        end

        class Stats < Base
          graphql_name "OnniStatsInput"
          argument :enabled, Boolean, required: false
          argument :sample_rate, Float, required: false
        end

        class Variant < Base
          graphql_name "OnniVariantInput"
          argument :name, String, required: true
          argument :weight, ::GraphQL::Types::BigInt, required: true
        end
      end
    end
  end
end
