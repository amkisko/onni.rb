# frozen_string_literal: true

gem "activesupport", ">= 7.2.3.2"
require "active_support"
require "active_support/notifications"
require "onni"

Onni.configuration.instrumenter = ActiveSupport::Notifications
