# Show/skip pressure and engineering audit

## Participants

Andrei Makarov (@amkisko), the operator named in the implementation plan.

## Decisions

Audit the current uncommitted show/skip implementation, then use measured
first-party candidates for individual optimize/prove cycles. The baseline is
that implementation, not HEAD. No dependency graph or runtime pin changes.

Pipeline: Ruby or admin command -> typed registry -> committed adapter state ->
request/cache copy -> evaluation -> sampler -> request buffer -> hourly counters
-> admin query/chart. There is no queue or external API in these local probes.

Run resource/budget, trace/identification, performance, contracts, lineage,
privacy, and cache lifecycle checks. Boundary/control covers local mutations,
stale reads, and failure feedback. There are no physical devices. Security scope
is the changed cache and telemetry paths; this is not a repository-wide security
assessment. Learned-systems mode is absent. Dependency fitness reassessment is
unnecessary: no measured blocker was assigned to a third-party package.

## Effects

### Confirmed findings and repairs

1. Medium severity, high confidence, observed. Location: Store cache fill and
   bust_cache!. A delayed fill could restore gates after a committed skip. A
   failing concurrent-reader spec demonstrated the sequence. Smallest fix:
   per-live-adapter namespace plus per-feature generation, advanced after the
   write commits. Metadata locking excludes adapter/cache IO. Obsolete-entry
   cleanup failure is logged without reversing the successful mutation.
2. Medium severity, high confidence, observed. Location: ActiveRecord StatWrites
   batch rows. Per-sample clamping discarded 1000016 counts from a valid summed
   batch. Smallest fix: preserve nonnegative aggregate totals while keeping
   individual sample weights bounded. The failing example now conserves counts.
3. Medium severity, high confidence, observed. Location: reset_request! and
   RequestLifecycle. Failed telemetry replaced a successful response or masked
   an application exception. Two failing examples now pass. Smallest fix: log
   the flush error class, preserve the application outcome, always clear request
   state. Explicit flush_stats! still raises; ambiguous writes are not retried.
4. Medium severity, high confidence, observed. Location: Memory gate ownership.
   Stored values aliased caller strings, and a partially mutated working copy
   could leak on failure. Smallest fix: owned deeply frozen published snapshots
   and independent mutable public row copies. New mutation, snapshot, and abort
   tests pass. Optional gates_snapshot_for avoids copying on evaluation;
   third-party adapters retain the gates_for fallback.
5. Medium severity, high confidence, observed. Location: admin FlagsQuery.
   Fifty configured flags required fifty gate SELECTs. Smallest fix: reuse the
   existing bulk preload, skip it when request data already contains every key.
   Request specs observe one gate SELECT with request_preload both off and on.
6. Low severity, high confidence, observed. Location: memory statistics bucket
   identity. A delimiter in a feature name broke string-key parsing. Smallest
   fix: owned feature string plus integer UTC hour; read, purge, and overview
   consumers changed together. Delimiter and caller-ownership specs pass.
7. Low severity, high confidence, observed. Location: evaluation and statistics
   paths. Repeated registry lookup, absent-condition arrays, per-row override
   interpolation, copied variant hashes, per-call legacy maps, repeated ignored
   name conversion, redundant rate coercion, disabled stats dispatch, repeated
   buffer publication, and formatted hour keys consumed measurable work. Apply
   the small local fixes in the fifteen recorded cycles. Every retained cycle
   improved its declared primary metric beyond its noise floor.

### Resource evidence and limits

Five isolated alternating samples, arm64-darwin24, Ruby 4.0.2. Each L1 sample
performs 100000 seven-path walks after 1000 warmups. Native peak RSS calibration
observed a touched 32 MiB fixture; stage sleep p95 fields remained separate from
aggregate CPU/wall. A/A median CPU differed by 0.3%; use a 3% directional floor.

Final paired median CPU is 1.838208 -> 1.398583 seconds (-23.9%); allocations
8089001 -> 4489001 (-44.5%). Maximum process-lifetime RSS is 41631744 -> 41910272
bytes; no memory reduction claim. Stats payload remains 657 serialized bytes.
Uncompressed lib/app/sig source is 93437 -> 95580 bytes. Three deterministic
gem builds per side produce 41984 -> 43008 compressed bytes (+1024).

The independent final gate passes all unchanged proposed limits: CPU
1.411893 <= 1.5332079s, wall 1.414540 <= 1.5369011500442866s, allocations
4489001 <= 6875650.85, peak RSS 42008576 <= 47989555.2 bytes, stats payload
657 <= 755.55 bytes, source 95580 <= 98108.85 bytes.
The promoted file also passes a fresh five-sample gate: CPU 1.429214s, wall
1.436717s, allocations 4489001, RSS 41730048 bytes, payload 657, source 95580.

Correctness has measured costs. Cache fencing alone costs 11.2% median CPU
against the preceding optimized build. Initial-to-final warm-cache CPU differs
by +1.0%, inside the directional floor; allocations fall 10.7%. Cache-accounted
bytes grow from 1069 to 1168 for one entry. Immutable gate writes finish at
+7.0% CPU and +11.8% allocations against the pre-snapshot build, after cycle 15
reduces the first implementation's cost. Do not call either repair a speedup.

One earlier absolute gate failed timing. Another failed while coverage workers
overlapped the benchmark. Retain those outcomes, rerun alone, keep limits fixed.
Later passes do not validate earlier failed measurements. The evidence bundle
labels the first failure as a recorded reading without retained raw samples.

Stock rotating-actor load and direct SQLite eight-writer gates pass their
existing ceilings. SQLite ladder steps 1, 2, 4, 8, 16 have zero lock waits and
write errors in retained median rows. Direct/buffer counts equal requested work;
sampled counts are estimates. Stock runner retains only its wall-median sample,
so no raw-variance or reliable RSS claim comes from that ladder. Explicit file
size is separate from its uninstrumented zero storage-delta fields.

CPU seconds are an energy proxy; joules, co-location effects, and network savings
are unmeasured. All fixtures are local. This is a step/load episode, not a soak
or sustained multi-process deployment test.

### Cache, trace, contracts, and coverage

Authority: YAML definitions and adapter gates. ActiveRecord persists overrides;
the memory adapter loses overrides when discarded. Request preload and shared
cache entries can be rebuilt from the adapter, then combined with YAML. Local
generations fence stale fills and namespace adapter replacement. Weak adapter
ownership releases metadata when an adapter is collected. Eviction/rebuild and
failed old-entry deletion are covered by executable specs.

Trace inventory captures event names and field names only. stats.record.onni
contains name/show/weight, not actor identity. Explicit actor mutations publish
actor_id in feature_operation.onni; group and percentage mutations publish their
own fields. YAML, gate rows, and cache values can contain targeted actor IDs.
The host chooses notification subscribers, cache access, and retention. No new
tracking identifier is introduced by evaluation. Random cache namespaces are
internal cache identity, not person identity. No payload values, hostnames, or
absolute paths enter the tracked benchmark evidence.

Lineage: kept sample weight -> per-feature show/skip buffer sums -> additive
hourly upsert -> stored count -> chart. Aggregate-clamp specs prove conservation;
middleware specs prove failure cleanup. Existing expiry, unknown-key,
hard-off, percentage, group, variant, and compatibility specs remain green.
Tests exercise behavior, not source text. No new futile assertion-only coverage
was identified in the changed specs. The referenced spec/README.md is absent.

Full suite: 202 examples, zero failures. Five coverage workers pass after moving
aside one stale coverage fragment; the clean merge contains five fragments.
Measured repository line coverage is 1238/1271 (97.4%). RuboCop checks 88 files,
RBS validates, locale parity passes. LOC warnings remain for app/admin/features.rb
(202) and lib/onni.rb (157). These are warnings, not failed checks.

Person-facing surface: ActiveAdmin Flags index. Request specs verify the same
index behavior with the smaller query budget. This episode changes no visual
layout, copy, interaction, or empty/loading/error presentation. A rendered narrow
viewport assessment was skipped; no new screenshot is claimed.

## Next

Stop this episode explicitly after one pilot and fourteen counted improvements,
passing unchanged absolute limits, and the full correctness checks. Further
representation changes or higher-cardinality actor/cache experiments need a
new named budget and episode; do not extend this run with clone cleanups.

Local cache generations do not synchronize different processes or direct
out-of-band database writes. TTL bounds entry age, not a global data version.
Concurrent cold misses are not collapsed. Generation metadata grows with distinct
mutated names for each live adapter. These are documented limits, not measured
capacity failures; next validation would use two processes, many distinct keys,
and a counted cold-miss burst before proposing broader cache semantics.

## Source

- [Live work](../issues/20261113071037_pressure-show-skip-evaluation.md)
- [Binding](../../benchmarks/show_skip_pressure_binding.md)
- [Raw evidence and exact commands](../../benchmarks/show_skip_pressure_results.json)
- [Promoted ceilings](../../benchmarks/show_skip_pressure_ceilings.json)
- [Cache regression specs](../../spec/onni/cache_consistency_spec.rb)
- [Request lifecycle specs](../../spec/onni/middleware/request_lifecycle_spec.rb)
