# frozen_string_literal: true

class AdminUser < ApplicationRecord
  def active_for_authentication?
    active
  end
end
