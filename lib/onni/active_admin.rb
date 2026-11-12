# frozen_string_literal: true

# First-class ActiveAdmin support for Onni.
# The Rails engine loads `app/admin` when ActiveAdmin is already defined.
# Require this file explicitly when you want to assert ActiveAdmin is present:
#
#   require "onni/active_admin"
#
require "onni"
require "onni/active_admin_routes"

raise LoadError, "ActiveAdmin is required for onni/active_admin" unless defined?(ActiveAdmin)

require "onni/engine" if defined?(Rails::Engine)
