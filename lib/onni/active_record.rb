# frozen_string_literal: true

gem "activerecord", ">= 7.2.3.2"
require "active_record"
require "onni"
require "onni/adapters/active_record"

module Onni
  autoload :Feature, "onni/active_record/feature"
  autoload :Gate, "onni/active_record/gate"
  autoload :StatBucket, "onni/active_record/stat_bucket"
end

Onni.register_adapter(:active_record) { Onni::Adapters::ActiveRecord.new }
