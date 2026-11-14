# frozen_string_literal: true

module Onni
  module Expirations
    class Error < StandardError; end

    module_function

    def status(definition, now: Time.now.utc)
      raw = definition["expires_at"]
      return :none if raw.nil? || raw.to_s.strip.empty?

      deadline = definition["expires_at_time"] || Time.parse(raw.to_s).utc
      (deadline < now) ? :overdue : :current
    rescue ArgumentError, TypeError
      :invalid
    end

    def verify!(mode: Onni.configuration.expires_at_verify, now: Time.now.utc)
      raise ArgumentError, "Expiration mode must be opt_in or all" unless %i[opt_in all].include?(mode)

      stale = Registry.config.filter_map do |name, definition|
        next unless mode == :all || definition["raise_on_expiration"] == true

        state = status(definition, now: now)
        "#{name} (#{state})" unless state == :current
      end
      raise Error, "Review feature expirations: #{stale.join(", ")}" unless stale.empty?

      true
    end
  end
end
