# Ops instrumentation audit

## Participants

Andrei Makarov (@amkisko)

## Decisions

Goal: make Onni hit retention hard to ignore and give hosts a subscribe hook without building a job runtime. Use ActiveSupport::Notifications for structured egress and an operator overview for retention visibility.

Pipeline: feature mutation / stats write / purge -> Instrumenter -> ActiveSupport::Notifications egress; overview read -> adapter count/min -> ActiveAdmin Hit storage panel. Observability mode applied. Resource and budget: no instrumentation on every `enabled?` (hot path); only kept stats writes, purge, and enable/disable. Trace and identification: payloads carry feature names and optional actor ids already present in gates; no new person identifiers. Security: unchanged. Boundary/control: skipped (no physical actuators).

Non-goals: database advisory locks for claim-once work, LISTEN/NOTIFY, in-gem cron, instrumenting every evaluation.

## Effects

Findings fixed:

- Medium (operability): retention cleanup existed but was invisible on the operator surface. Added `Onni.stats_overview` / `Stats::Overview` and an ActiveAdmin Hit storage panel (bucket count, oldest hour, retention, past-retention and large-table guidance).
- Medium (observability): no structured hooks for host metrics. Added `Onni::Instrumenter` publishing `stats.record.onni`, `stats.purge.onni`, and `feature_operation.onni` for enable/disable.
- Low (docs): README instrumentation + overview section; generator copy already stresses daily schedule.

Validation: `bundle exec rspec` -> 71 examples, 0 failures.

## Next

- Done: commented subscribe example in initializer template.
- Done: `feature_operation.onni` also covers `enable_group`, `disable_group`, `enable_percentage_of_actors`, `set_variants`.

## Source

- `lib/onni/instrumenter.rb`
- `lib/onni/stats/overview.rb`
- `app/admin/features.rb`
