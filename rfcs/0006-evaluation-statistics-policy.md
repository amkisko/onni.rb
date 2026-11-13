# RFC 0006: Evaluation statistics policy

- Type: Standards Track
- Status: Draft
- Created: 2026-11-13
- Author: Andrei Makarov
- Relates: RFC-0003, RFC-0005

## Summary

Record every completed evaluation of a known flag by default, including pending
and parked misses. Support explicit call-site decisions, feature defaults, and
runtime feature statistics settings without rebuilding the adapter.

## Motivation

Pending and parked early returns currently hide calls to visible? from the
evaluation history. Operators cannot distinguish an unused feature from one
that is queried while off. Collection controls belong at the call site, feature,
and application levels.

## Guide-level explanation

visible?(name, actor = nil, record_stats: nil) inherits collection settings.
false skips collection for that call. true opts in even when feature-level
collection is disabled. The application stats_enabled master switch and
stats_ignore list still veto recording. Sampling still applies.

Feature YAML may contain stats: {enabled: true, sample_rate: 1.0}. Both fields
are optional. Without them, collection is enabled and the application sampling
rate applies. The core and generated initializer default to collecting all calls.

stats!(name, enabled: false, sample_rate: 0.25) changes only named settings,
atomically, without changing power or audiences. A nil value removes that
runtime override and restores the YAML or application default for that field.
Onni[name].stats_settings reads the effective defaults without evaluating a flag.
clear! removes these overrides; park! preserves them.

## Reference-level explanation

Known visible? calls record shown_count when true and skip_count when false,
including pending, parked, expired, condition, and audience misses. Known variant
calls record shown_count when assigned and skip_count when nil, including missing
actors, empty weights, and non-experiment flags. Unknown names remain false/nil
without allocating stats rows. Exceptions do not invent an evaluation outcome.
Power predicates and configuration reads never record statistics.

Collection defaults resolve runtime feature enabled, then YAML feature enabled,
then true. An explicit record_stats option replaces that feature choice. The
global master switch and ignore list remain hard vetoes. Rate defaults resolve
runtime feature sample_rate, then YAML, then application stats_sample_rate.
The existing application sampler may override that rate, or return nil to use it.
Its context and event payload remain name/shown; no actor or group stats keys.

Feature enabled accepts booleans. Feature sample_rate accepts finite integers or
floats in 0..1. YAML null, unknown keys, and malformed feature settings raise
ArgumentError. Runtime nil means inherit. Invalid call-site options raise before
evaluation. Corrupt persisted feature stats fail closed for collection.

The stats gate holds a JSON mapping of runtime overrides. Parsed gate snapshots
include it; representation keys advance to v4. Committed writes use existing
adapter transactions and local generation invalidation. YAML and gate rows are
authoritative; parsed snapshots, request preloads, and application cache entries
are rebuildable. Existing cross-process freshness limits remain unchanged.

Onni.configure preserves the current adapter when changing ordinary settings.
Changing adapter selection or concurrency deliberately rebuilds it. Runtime
configuration changes do not migrate stored data or queued buffers. Flush
accepted buffered counts before changing adapter. Turning buffering off preserves
accepted counts until the next explicit flush or request reset.

## Drawbacks

Off-state traffic now creates skip writes and changes shown_share denominators.
An unbuffered recorded evaluation adds one adapter write; buffering aggregates
by feature/hour. Hosts can opt out, sample, or buffer. Inspect-only calls must
use record_stats: false. Historical periods retain their earlier counting scope.

## Rationale and alternatives

Count calls independently of visibility so off-state usage remains observable.
Keep explicit opt-out and sampling rather than silently excluding power states.
Use existing gate storage and two focused feature controls; do not introduce a
second global configuration format in features.yml or identity-keyed telemetry.

## Prior art

Stats::Sampler already provides application controls and Store exposes a
record_stats keyword. This extends those controls with feature configuration.

## Unresolved questions

Maintainer review and release selection remain. Cross-process invalidation,
deduplication, and arbitrary runtime migration of adapters or buffers are outside
this change.
