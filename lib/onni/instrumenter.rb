# frozen_string_literal: true

module Onni
  module Instrumenter
    module_function

    def instrument(name, payload = {})
      bus = Onni.configuration.instrumenter
      if bus
        bus.instrument("#{name}.onni", payload) do |event_payload|
          yield(event_payload) if block_given?
        end
      elsif block_given?
        yield(payload)
      end
    end

    def warn(message)
      Onni.configuration.logger&.warn(message)
    rescue
      nil
    end
  end
end
