# frozen_string_literal: true

module Onni
  # Publishes ActiveSupport::Notifications with a `.onni` suffix
  # (for example `stats.record.onni`).
  module Instrumenter
    module_function

    def instrument(name, payload = {})
      bus = notifications_bus
      if bus
        bus.instrument("#{name}.onni", payload) do |event_payload|
          yield(event_payload) if block_given?
        end
      elsif block_given?
        yield(payload)
      end
    end

    def notifications_bus
      return unless defined?(ActiveSupport::Notifications)

      ActiveSupport::Notifications
    end
    private_class_method :notifications_bus
  end
end
