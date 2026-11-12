# frozen_string_literal: true

module Onni
  class StatBucket < ::ActiveRecord::Base
    self.table_name = "onni_feature_stat_buckets"

    belongs_to :feature, class_name: "Onni::Feature", foreign_key: :feature_key,
      primary_key: :key, inverse_of: :stat_buckets, optional: true

    validates :feature_key, :period, :period_start, presence: true
  end
end
