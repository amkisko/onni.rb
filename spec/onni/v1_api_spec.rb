# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Onni terminology API" do
  it "rejects removed power, evaluation, slice, and dial names" do
    %i[enable disable enabled? disabled? enable_group disable_group
      enable_percentage_of_actors set_variants show! skip! show? skip?
      show_group! skip_group! show_actor! skip_actor! show_percentage!
      skip_percentage! percentage start! pause!].each do |method|
      expect { Onni.public_send(method, :new_checkout) }.to raise_error(NoMethodError)
    end
    %i[show? enabled? skip? percentage].each do |method|
      expect { Onni[:new_checkout].public_send(method) }.to raise_error(NoMethodError)
    end
    expect { Onni::Store.enabled?(:new_checkout) }.to raise_error(NoMethodError)
  end
end
