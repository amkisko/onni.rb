# frozen_string_literal: true

module Onni
  module Adapters
    autoload :Memory, "onni/adapters/memory"

    @factories = {memory: -> { Memory.new }}.freeze

    module_function

    def register(name, &factory)
      unless factory && name.respond_to?(:to_sym) && !name.to_s.empty?
        raise ArgumentError, "Register a named adapter factory"
      end

      Sync.synchronize { @factories = @factories.merge(name.to_sym => factory).freeze }
    end

    def build(name)
      factory = Sync.synchronize { @factories[name.to_sym] } if name.respond_to?(:to_sym)
      raise ArgumentError, "Unknown Onni adapter #{name.inspect}" unless factory

      factory.call
    end
  end
end
