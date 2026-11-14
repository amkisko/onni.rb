# RFC 0009: Integer signals and park reasons

- Type: Standards Track
- Status: Experimental
- Created: 2026-11-14
- Author: Codex

## Summary

Add bounded, named integer signals independent of shown/skip statistics.
Apply signal updates and threshold parking atomically on the feature.

## Motivation

Implement the delivery and operator workflow agreed in the
[delivery plan](../docs/plans/20261114103806_exception-rate-park-and-error-stats.md).

## Guide-level explanation

Declare signals: {exception: {threshold: 25}} in the catalogue. Call
Onni.observe!(name, :exception) when a failure should count. At 25, ready power
parks. Reset the signal after recovery and explicitly call ready! to resume.

## Reference-level explanation

observe!(name, signal, delta = 1) returns the committed integer level.
signal_level reads the adapter directly. reset_signals!(name, signal = nil)
resets one/all levels without changing power. signals!(name, **policies) changes
threshold overrides; threshold: nil disables automatic parking for that key.
Catalogue signals maps names to {threshold: positive Integer or nil}.
:exception is always allowed; other keys must be declared by catalogue/policy.
Allow at most 32 keys including exception, each matching [a-z][a-z0-9_]{0,63}.
Deltas and resulting levels must fit signed 64-bit integers; negatives heal
without automatically making power ready. No sampling or buffering applies.
An update at/above its effective threshold parks only if power is ready.
park!(name, reason: nil) accepts an optional string of at most 128 bytes;
automatic reason is signal:<key>. Both use the existing powered gate.
Signal policy, levels and power use the adapter's serialized update_gates
transaction/lock. No separately checked ready? read may race ready!/reset.
Emit feature_operation observe and park only after all enclosing ActiveRecord
transactions commit. Rollback discards events. Bypass serving caches for
transaction-local reads, and invalidate again after commit. Request preloads carry the current transaction identity and cannot be reused
after commit/rollback or an adapter change. Custom adapters may implement
after_commit and gate_read_context; absent hooks imply immediate effects.
Store levels in the signal_levels JSON gate, policies in signals. clear! drops
runtime policy/power/targeting but retains levels and historical stats.
Notifications report committed successes and are best-effort telemetry, with
no durable event replay. They do not measure write latency. Mutation failures
propagate to callers without a success event.
Memory is ephemeral; ActiveRecord gates are durable. Clearing caches rebuilds
from adapter gates; resetting a memory adapter loses its only state copy.
Gate cache prefix becomes v5. Cached selection remains bounded by cache_ttl
and request preloading. No cache gives fresh next-call reads, not cancellation
of an experiment already executing. signal_level bypasses these caches.

## Drawbacks

Hosts must load Ruby catalogue definitions in each evaluating process and review
changed contracts before deployment. Serialized writes bound throughput on a
single hot feature. Cached reads are not a fleet-wide instant stop mechanism.

## Rationale and alternatives

Reuse the existing power machine and adapter gates. Keep ordinary boolean flags
and assignment-only variants available. Avoid an additional power state or
unbounded analytics storage.

## Prior art

Existing Onni power, targeting, stats and programmatic-definition contracts in
RFC-0003, RFC-0005, RFC-0006 and RFC-0007.

## Unresolved questions

No unresolved implementation choices. Maintainers still review the experimental
contract before release.
