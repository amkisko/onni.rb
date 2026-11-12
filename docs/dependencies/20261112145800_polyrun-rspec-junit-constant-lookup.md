# polyrun RspecJunit bare RSpec resolves to Polyrun::RSpec

## Participants

Andrei Makarov (@amkisko)

## Dependency

- name: polyrun
- version constraint: >= 3.0.0
- lockfile: Gemfile.lock polyrun (3.0.0)

## Symptom

`Polyrun::Reporting::RspecJunit.install!` raised `NoMethodError: undefined method 'configure' for module Polyrun::RSpec` when `require "polyrun/rspec"` had already defined `Polyrun::RSpec`.

## Evidence

1. `require "polyrun/rspec"` then `Polyrun::Reporting::RspecJunit.install!` with `CI=1`
2. `lib/polyrun/reporting/rspec_junit.rb` called bare `RSpec.configure` inside `Polyrun::Reporting`
3. Constant lookup found `Polyrun::RSpec` before `::RSpec`

## Suggested fix

Upstream: use `::RSpec` in `RspecJunit.install!` (and any other reporting helpers under `Polyrun::`). Host workaround on 2.2.9: call `RspecJunit.install!` before `require "polyrun/rspec"`.

## Effects

- Fixed in polyrun 3.0.0 (`::RSpec` qualification) together with renaming `Polyrun::RSpec` to `Polyrun::RSpecSupport`.
- Host adapted: `spec/spec_helper.rb` requires `polyrun/rspec_support` and calls `Polyrun::RSpecSupport`; install-order workaround removed.

## Next

- None for this defect.

## Source

- `spec/spec_helper.rb`
- polyrun `CHANGELOG.md` 3.0.0
- polyrun `lib/polyrun/reporting/rspec_junit.rb`
