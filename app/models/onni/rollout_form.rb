# frozen_string_literal: true

module Onni
  class RolloutForm
    include ActiveModel::Model

    attr_accessor :percentage, :group_name, :group_action, :control, :treatment

    def self.model_name
      ActiveModel::Name.new(self, nil, "Feature")
    end
  end
end
