# frozen_string_literal: true

Rails.application.routes.draw do
  ActiveAdmin.routes(self)
  Onni::ActiveAdminRoutes.draw(self)
end
