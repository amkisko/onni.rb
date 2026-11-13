# frozen_string_literal: true

module Onni
  class Gate < ::ActiveRecord::Base
    self.table_name = "onni_feature_gates"

    belongs_to :feature, class_name: "Onni::Feature", foreign_key: :feature_key,
      primary_key: :key, inverse_of: :gates, optional: true

    validates :feature_key, :key, :value, presence: true
  end
end
