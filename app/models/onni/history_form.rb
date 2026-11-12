# frozen_string_literal: true

module Onni
  class HistoryForm
    include ActiveModel::Model

    attr_accessor :range

    def self.model_name
      ActiveModel::Name.new(self, nil, "History")
    end
  end
end
