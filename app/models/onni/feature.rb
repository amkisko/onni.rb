# frozen_string_literal: true

module Onni
  class Feature < ::ActiveRecord::Base
    self.table_name = "onni_features"

    has_many :gates, class_name: "Onni::Gate", foreign_key: :feature_key, primary_key: :key,
      dependent: :delete_all, inverse_of: :feature
    has_many :stat_buckets, class_name: "Onni::StatBucket", foreign_key: :feature_key,
      primary_key: :key, dependent: :delete_all, inverse_of: :feature

    validates :key, presence: true, uniqueness: true
  end
end
