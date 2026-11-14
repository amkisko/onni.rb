# frozen_string_literal: true

module Onni
  class Delivery
    module Declarations
      DEFAULT_RESCUE_POLICY = {signal: :exception, count_programming_errors: false}.freeze
      KEYWORDS = %w[alias and begin break case class def defined do else elsif end ensure false for if
        in module next nil not or redo rescue retry return self super then true undef unless until when while yield].freeze
      RESERVED = %w[parked on call feature experiment object selected deliver rescue_policy].freeze

      attr_reader :feature_name

      def feature(name, **settings)
        raise ArgumentError, "Delivery already has a feature" if @feature_name

        Delivery.check_binding!(name, self)
        unless settings.empty?
          Registry.define_delivery!(name, self, **settings)
        end
        Registry.require_definition!(name)
        @feature_name = name.to_s
        Delivery.register(name, self)
      end

      def experiments
        @experiments ||= {}.freeze
      end

      def experiment(name, **filters, &block)
        raise ArgumentError, "Declare a feature before experiments" unless feature_name

        key = name.to_s
        validate_experiment_name!(key)
        changes = filters.transform_keys(&:to_s)
        Registry.validate_filters!(changes, nullable: false)
        Delivery.validate_variants!(feature_name, Onni[feature_name].variants, [key])
        @experiments = experiments.merge(key => Registry.copy_definition(changes)).freeze
        define_method(key, &block) if block
      end

      def parked(&block)
        raise ArgumentError, "Provide the parked body" unless block

        define_method(:parked, &block)
      end

      def policy
        @policy || DEFAULT_RESCUE_POLICY
      end

      def rescue_policy(signal: policy[:signal], count_programming_errors: policy[:count_programming_errors])
        SignalPolicy.validate_name!(signal)
        if feature_name
          SignalPolicy.require_key!(Registry.require_definition!(feature_name), Onni.adapter.gates_for(feature_name), signal)
        end
        unless [true, false].include?(count_programming_errors)
          raise ArgumentError, "count_programming_errors must be boolean"
        end
        @policy = {signal: signal.to_sym, count_programming_errors: count_programming_errors}.freeze
      end

      def validate!
        raise ArgumentError, "Declare a feature" unless feature_name

        missing = (["parked"] + experiments.keys).reject { |key| public_method_defined?(key) }
        raise ArgumentError, "Missing Delivery bodies: #{missing.join(", ")}" unless missing.empty?
      end

      private

      def validate_experiment_name!(key)
        forbidden = RESERVED + KEYWORDS + instance_methods.map(&:to_s) + private_instance_methods.map(&:to_s)
        unless key.match?(/\A[a-z][a-z0-9_]{0,63}\z/) && !forbidden.include?(key) && !experiments.key?(key)
          raise ArgumentError, "Invalid or reserved experiment #{key}"
        end
      end
    end
  end
end
