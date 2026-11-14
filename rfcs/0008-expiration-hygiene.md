# RFC 0008: Expiration hygiene

- Type: Standards Track
- Status: Experimental
- Created: 2026-11-14
- Author: Codex

## Summary

Treat expires_at as catalogue maintenance metadata. It never affects power,
visibility, variant assignment, Delivery routing, or evaluation statistics.

## Motivation

Implement the delivery and operator workflow agreed in the
[delivery plan](../docs/plans/20261114103806_exception-rate-park-and-error-stats.md).

## Guide-level explanation

Call Onni.verify_expirations! from a dedicated host spec. Mark selected
definitions raise_on_expiration: true, or check every definition with mode: :all.
An overdue definition stays available until an operator explicitly parks it.

## Reference-level explanation

Onni.verify_expirations! checks overdue and unparseable dates and raises
Onni::Expirations::Error listing names. Configuration expires_at_verify defaults
to :opt_in (only raise_on_expiration: true), and also accepts :all. The caller
may override mode and now. Checks never run implicitly during boot/evaluation.
Flag#expiration_status returns :current, :overdue, :invalid, or :none.
ActiveAdmin marks overdue/invalid metadata. Ruby definitions require parseable
nonblank timestamps; compatibility YAML can retain invalid metadata for review.
raise_on_expiration must be boolean. An absent expiry fails :all verification.
This replaces RFC-0003 expiration gating; overdue flags can now produce shown
counts. Hosts that need an actual stop must call park!.

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
