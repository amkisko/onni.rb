# frozen_string_literal: true

module Onni
  module Group
    @registry = {}.freeze

    module_function

    def register(name, &block)
      Sync.synchronize do
        next_registry = @registry.dup
        next_registry[name.to_sym] = block
        @registry = next_registry
      end
    end

    def clear!
      Sync.synchronize { @registry = {} }
    end

    def names
      Sync.synchronize { @registry.keys }
    end

    def known?(name)
      Sync.synchronize { @registry.key?(name.to_sym) }
    end

    def member?(name, actor)
      block = Sync.synchronize { @registry[name.to_sym] }
      return false unless block

      block.call(actor, name.to_sym)
    end
  end
end
