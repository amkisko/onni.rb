# frozen_string_literal: true

module AudienceFilterCases
  State = Data.define(:label, :value, :audience, :opener)
  Scenario = Data.define(:filters, :audience, :description)
  UNIVERSE = %i[anonymous beta staff].freeze
  DEFAULT_LABELS = {"everyone" => :on, "level" => :below_both}.freeze
  OVERRIDE_LABELS = {"everyone" => :off, "level" => :both}.freeze
  PASSING_LABELS = {
    "everyone" => :on, "excluded_groups" => :empty,
    "excluded_actors" => :empty, "level" => :full
  }.freeze

  module_function

  def state(label, value, audience, opener: false)
    State.new(label, value, audience, opener)
  end

  DIMENSIONS = {
    "everyone" => [
      state(:absent, nil, UNIVERSE),
      state(:off, false, UNIVERSE),
      state(:on, true, UNIVERSE, opener: true)
    ],
    "groups" => [
      state(:absent, nil, UNIVERSE),
      state(:empty, [], [], opener: true),
      state(:beta, ["beta_testers"], [:beta], opener: true),
      state(:staff, ["staff"], [:staff], opener: true),
      state(:both, %w[staff beta_testers], %i[beta staff], opener: true)
    ],
    "actors" => [
      state(:absent, nil, UNIVERSE),
      state(:empty, [], [], opener: true),
      state(:beta, ["User;29"], [:beta], opener: true),
      state(:staff, ["User;5"], [:staff], opener: true),
      state(:both, %w[User;5 User;29], %i[beta staff], opener: true)
    ],
    "excluded_groups" => [
      state(:absent, nil, UNIVERSE),
      state(:empty, [], %i[beta staff]),
      state(:beta, ["beta_testers"], [:staff]),
      state(:staff, ["staff"], [:beta]),
      state(:both, %w[staff beta_testers], [])
    ],
    "excluded_actors" => [
      state(:absent, nil, UNIVERSE),
      state(:empty, [], %i[beta staff]),
      state(:beta, ["User;29"], [:staff]),
      state(:staff, ["User;5"], [:beta]),
      state(:both, %w[User;5 User;29], [])
    ],
    "level" => [
      state(:absent, nil, UNIVERSE),
      state(:zero, 0, [], opener: true),
      state(:below_both, 49, [], opener: true),
      state(:beta_only, 50, [:beta], opener: true),
      state(:both, 51, %i[beta staff], opener: true),
      state(:full, 100, %i[beta staff], opener: true)
    ]
  }.freeze

  def scenario(states)
    selected = DIMENSIONS.keys.zip(states).to_h
    audience = states.any?(&:opener) ? states.map(&:audience).reduce(UNIVERSE, :&) : []
    Scenario.new(selected.transform_values(&:value), audience,
      selected.transform_values(&:label).inspect)
  end

  ROWS = DIMENSIONS.values.first.product(*DIMENSIONS.values.drop(1)).map { |states| scenario(states) }.freeze

  def presence_rows
    choices = DIMENSIONS.map do |key, states|
      [states.first, states.find { |entry| entry.label == PASSING_LABELS.fetch(key, :both) }]
    end
    choices.first.product(*choices.drop(1)).map { |states| scenario(states) }
  end

  def precedence_rows
    choices = DIMENSIONS.map do |key, states|
      default = states.find { |entry| entry.label == DEFAULT_LABELS.fetch(key, :beta) }
      override = states.find { |entry| entry.label == OVERRIDE_LABELS.fetch(key, :staff) }
      [[false, default], [true, override], [true, states.first]]
    end
    choices.first.product(*choices.drop(1)).map do |entries|
      effective = scenario(entries.map(&:last))
      changes = DIMENSIONS.keys.zip(entries).filter_map { |key, (set, entry)| [key, entry.value] if set }.to_h
      Scenario.new(changes, effective.audience, entries.map { |set, entry| [set, entry.label] }.inspect)
    end
  end
end
