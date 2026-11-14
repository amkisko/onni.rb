# Delivery, signals and catalogue changes

## Participants

Andrei Makarov.

## Decisions

Implement RFC-0008 through RFC-0011. Prefer Ruby catalogue definitions; retain
YAML input for compatibility. Keep optional weighted Delivery selection and
per-experiment power for later design work. Include this work in gem cut 3.0.0;
deliver with `make release`.

## Effects

Add Onni::Delivery and Onni.deliver with a required parked path, ordered
experiment targeting, one return value, and experiment-only fallback. Preserve
ActiveRecord::Rollback and exit-like exceptions. Programming errors fall back
without increasing signal levels unless the host opts in.

Add signed integer observations, bounded retained levels, runtime thresholds,
signal reset and park reasons. Atomically combine a threshold observation and
power park on the existing gate path. Reset does not ready power. clear! keeps
levels and historical evaluation counts. No database migration is required.

Publish mutation notifications after commit. Discard them on rollback and bind
request preloads to the current transaction, preserving batched reads while
preventing uncommitted gate data from escaping into shared caches. Raw exception
messages and actor arguments are omitted from Delivery error telemetry.

Change expires_at from a visibility gate to maintenance metadata. Overdue ready
features can now produce shown counts and different shown_share values. Hosts
that used expiry to stop rollout must explicitly park. Add opt-in verification
for host specs/CI and visible overdue/invalid labels in ActiveAdmin.

Add YAML/JSON/CSV catalogue export and the four shipped rake tasks. CSV export
works with the declared zero-runtime-dependency core, including quoted fields
and embedded newlines. Add ActiveAdmin experiment targeting, signal thresholds,
reset and evaluation-count settings, keeping invalid input visible for correction.

Engineering audit and calibrated pressure evidence are linked below. Cut under
`## 3.0.0 (2026-11-14)`.

## Next

Deliver with `make release`. Review real host callbacks and cache freshness
requirements during adoption.

## Source

- [Plan](../plans/20261114103806_exception-rate-park-and-error-stats.md)
- [Live work](../issues/20261114113817_delivery-signals-and-catalogue.md)
- [Implementation review](../reviews/20261114123346_delivery-implementation-audit.md)
- [RFC-0008](../../rfcs/0008-expiration-hygiene.md)
- [RFC-0009](../../rfcs/0009-integer-signals.md)
- [RFC-0010](../../rfcs/0010-delivery-experiments.md)
- [RFC-0011](../../rfcs/0011-catalogue-export.md)
