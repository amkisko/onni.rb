# frozen_string_literal: true

module Onni
  module Middleware
    # Optional Rack wrapper: preload gates at request start, always reset_request! after.
    # Enables stats_buffer flush without a host around_action when the engine is mounted.
    class RequestLifecycle
      def initialize(app)
        @app = app
      end

      def call(env)
        Onni.preload! if Onni.configuration.request_preload
        @app.call(env)
      ensure
        Onni.reset_request!
      end
    end
  end
end
