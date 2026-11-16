# frozen_string_literal: true

Rails.application.routes.draw do
  ActiveAdmin.routes(self)
  namespace :admin do
    ActiveAdmin::DeviceAuthorization::Routes.draw(self, consent: :controller)
  end
end
