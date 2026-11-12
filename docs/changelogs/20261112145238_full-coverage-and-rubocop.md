# Full line coverage and clean RuboCop

## Participants

Andrei Makarov (@amkisko)

## Decisions

Close remaining executable gaps under polyrun line coverage and keep RuboCop clean, including concurrency specs that intentionally start threads.

## Effects

- Specs cover adapter build paths, admin update/disable actions, hit-storage panel states, Sync/Instrumenter edge cases, memory clear/replace, AR replace_gates, and Engine.boot_sync_registry!
- Instrumenter uses a stubbable notifications bus for hosts without ActiveSupport::Notifications
- RuboCop: no offenses; ThreadSafety/NewThread excluded for concurrency specs
- `bundle exec rubocop`: 55 files, 0 offenses
- `POLYRUN_COVERAGE=1 bundle exec rspec`: 103 examples, 0 failures; 100.00% lines (725 / 725)

## Source

- `coverage/coverage-summary.txt`
