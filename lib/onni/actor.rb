# frozen_string_literal: true

module Onni
  module Actor
    module_function

    def id(actor)
      return if actor.nil?
      return actor.feature_actor_id if actor.respond_to?(:feature_actor_id)

      "#{actor.class.name};#{actor.id}"
    end

    def percentage_value(actor, feature_key)
      raw = id(actor).to_s
      Zlib.crc32("#{feature_key}:#{raw}") % 100
    end

    def variant_for(actor, feature_key, variants)
      return if actor.nil? || variants.blank?

      score = percentage_value(actor, feature_key)
      cursor = 0
      variants.each do |name, weight|
        cursor += weight.to_i
        return name.to_sym if score < cursor
      end
      variants.keys.last&.to_sym
    end
  end
end
