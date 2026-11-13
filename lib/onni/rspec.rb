# frozen_string_literal: true

require "onni"

module Onni
  # Host RSpec helper: memory adapter and a clean request store per example.
  # require "onni/rspec" then Onni::RSpec.install!
  module RSpec
    module_function

    def reset!
      Onni.configuration.adapter = :memory
      Onni.reset_adapter!
      Onni.reset_request!
    end

    def install!(rspec_config = ::RSpec.configuration)
      rspec_config.before { reset! }
    end
  end
end
