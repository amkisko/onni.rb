# Ops instrumentation and hit storage overview

## Participants

Andrei Makarov (@amkisko)

## Decisions

Ship ActiveSupport::Notifications hooks and an operator overview so retention cleanup stays visible without embedding a job runtime.

## Effects

- Events: `stats.record.onni`, `stats.purge.onni`, `feature_operation.onni`
- `Onni.stats_overview` + ActiveAdmin Hit storage panel
- Specs for instrumenter, overview, stats events, admin panel
- `bundle exec rspec`: 71 examples, 0 failures

## Next

- None required for merge beyond host scheduling of purge job.

## Source

- `docs/reviews/20261112164000_ops-instrumentation-audit.md`
