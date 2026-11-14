# RFC 0011: Catalogue export

- Type: Standards Track
- Status: Experimental
- Created: 2026-11-14
- Author: Codex

## Summary

Export one generated feature catalogue as YAML, JSON or CSV, with optional
runtime snapshot fields and shipped rake entry points.

## Motivation

Implement the delivery and operator workflow agreed in the
[delivery plan](../docs/plans/20261114103806_exception-rate-park-and-error-stats.md).

## Guide-level explanation

Load the Ruby catalogue in the host, then call Onni.export_catalogue or run
rake onni:export_json OUTPUT=tmp/catalogue.json. Use runtime: true on the Ruby
API when a snapshot of effective rollout settings is needed.

## Reference-level explanation

Onni.export_catalogue(format: :yaml, runtime: false, io: nil) returns a string
or writes that same string to io. Accept symbol/string yaml/json/csv only.
Export known definitions in name order, including descriptions, expires_at,
raise_on_expiration, audience/conditions/variants/stats/signals, and declared
experiments with default filters. Exclude cached parsed timestamps and bodies.
Runtime mode adds power, effective audience/variants/stats/signals, signal
levels and effective experiment targeting. Read each feature's gates once;
the complete export is a sequence of per-feature snapshots, not a transaction.
CSV has columns name, experiment, definition, runtime. Definition/runtime are
JSON objects. Use one row per experiment, or a blank experiment for features
without Delivery arms. JSON/YAML use one object per feature; CSV groups the
same logical feature object and selects its experiment entry per row.
No actor, callback body, exception text, credentials or timestamps of individual
calls are exported. Audience identifiers are definition data: export is a
maintainer operation, and hosts control distribution of generated files.
Tasks onni:export (FORMAT defaults yaml), onni:export_yaml, onni:export_json,
onni:export_csv use OUTPUT if supplied, otherwise stdout. Specific tasks ignore
FORMAT. Rails loads tasks via the engine and environment; standalone hosts
load onni/tasks after loading their catalogue. Tasks fail on invalid formats
before writing. Export files are output, never automatically loaded as input.

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
