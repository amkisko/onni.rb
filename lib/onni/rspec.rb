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
      # RSpec runs before hooks via instance_exec on the example; qualify the call.
      rspec_config.before { Onni::RSpec.reset! }
    end
  end
end
