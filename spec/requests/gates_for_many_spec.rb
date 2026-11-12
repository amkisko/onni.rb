# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Onni ActiveRecord gates_for_many", type: :request do
  it "loads gates for many keys with one Gate relation query" do
    Onni.enable(:demo)
    Onni.enable_percentage_of_actors(:search_v2, 25)

    expect(Onni::Gate).to receive(:where).once.and_call_original

    loaded = Onni.adapter.gates_for_many(%w[demo search_v2 missing])
    expect(loaded["demo"]).to include(hash_including("key" => "boolean"))
    expect(loaded["search_v2"]).to include(hash_including("key" => "percentage_of_actors"))
    expect(loaded["missing"]).to eq([])
  end
end
