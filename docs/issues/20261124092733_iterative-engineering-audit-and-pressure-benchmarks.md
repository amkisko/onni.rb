# Iterative engineering audit and pressure benchmarks

## Participants

Current session operator (display name unavailable in the session).

## Decisions

Audit Ruby flag evaluation, request preload and statistics buffering, cache
invalidation, memory and SQLite adapters, catalogue export, and the ActiveAdmin
and GraphQL readers. Use revision `381545ba46acf23f792ec55df36098be3dc4c4df`
as the baseline. Reproduce correctness defects before fixing them. Use a
single primary metric and five alternating isolated samples per candidate.

The November 24, 2026 run used Ruby 4.0.2 on arm64 Darwin. The fixtures used
local SQLite files and in-process state. CPU time served as the energy proxy.
Peak RSS included interpreter startup and fixture setup. SQLite storage counted
the database and sidecars. Memory storage used retained row counts and serialized
overview bytes. Production PostgreSQL and deployed caches need host fixtures.

The initial ladder used three samples at each load with `N` increasing by 5x.
Set a 3 percent acceptance floor and 1.15x headroom on median CPU, wall time
and allocations, and on maximum peak RSS. Use exact limits for query counts
and retained storage. Use the existing Delivery source ceiling for shipped
source bytes.

## Effects

### Confirmed findings and repairs

- Medium, high confidence. SQLite treated `batch_size: -1` as unbounded and
  deleted all three eligible rows in one queued page in the baseline fixture.
  Purge now requires a positive integer before it reads or deletes a page.
  The public-entry regression spec verifies that an eligible row survives.
- Medium, high confidence. A logger exception could escape a statistics write
  failure, mask an application exception during cleanup, or make a committed
  park appear to fail after obsolete-cache deletion failed. Warning delivery
  is now best-effort on these paths. All three regression examples pass.
- Medium, high confidence. Runtime catalogue export issued one gate query
  per flag. It now shares the bulk lookup with preload and GraphQL. An
  adapter with individual reads uses the same fallback as those consumers.
- Medium, high confidence. Memory purge built timestamps and sorted all
  remaining expired buckets on every page while holding the adapter lock. It
  now compares integer bucket hours and selects at most one batch. Before and
  after runs each retained one newer row after deleting 10,000 expired rows.
- Low, high confidence. Read paths repeatedly built unused timestamps,
  record models, and gate snapshots. Memory reads now build result timestamps
  only when needed. SQLite reads select the required columns. Gate reads share
  an immutable empty snapshot and construct legacy override keys once per scan.

YAML or host declarations and committed adapter gates supply evaluation state.
Request and application-cache copies rebuild from the adapter. Local delayed
fills and cache eviction are covered by specs. Cross-process freshness depends
on the host's TTL. Ordinary hit statistics contain flag key, outcome and weight.
Explicit audience writes and runtime export may carry actor identifiers.
Host configuration controls log subscribers, storage and export access. The
benchmarks used generated records.

### Pressure results

Calibration passed with distinct lookup, evaluation and recording p95 values,
separate aggregate wall time, and native RSS above the 32 MiB allocation
fixture. A same-source catalogue comparison varied by 0.06 percent in median
CPU. The following candidate results compare successive source snapshots at the
pressure load. Counts are median Ruby allocations unless otherwise indicated.

1. Select one memory purge page per pass (10,000 rows). CPU 670.11 to 5.48 ms.
2. Compare integer hours during purge (10,000 rows). Allocations 33,699 to 13,694.
3. Filter memory history before building timestamps (2,500 old buckets).
   Allocations 751,026 to 251,525.
4. Find the oldest stored hour before building the overview timestamp (5,000
   old buckets). Allocations 1,000,723 to 727.
5. Share an immutable empty snapshot (100,000 pending evaluations).
   Allocations 1,000,063 to 51.
6. Build legacy override keys outside row scans (15,000 snapshots of 80 rows).
   Allocations 3,750,016 to 1,380,016.
7. Select single-feature gate columns (three passes of 500 flags).
   Allocations 202,552 to 180,052.
8. Select multi-feature gate columns (three passes of 1,000 flags).
   Allocations 153,429 to 109,431.
9. Select SQLite history columns (12 passes of 500 buckets).
   Allocations 96,337 to 44,385.
10. Batch runtime export gate reads (three exports of 500 flags). Queries
    1,500 to 3. CPU 106.71 to 19.74 ms in the same comparison.
11. Reuse a clock read during 1,500 SQLite writes. CPU 171.76 to 169.13 ms.
    Reverted because the 1.5 percent difference fell below the acceptance floor.
12. Deduplicate frozen strings in memory bucket keys (125,000 writes).
    Allocations 375,024 to 250,023.

The final combined build passed all eleven workload gates with five samples
each. The initial and final 10,000-row purge CPU medians were 702.99 and
2.63 ms. Uncompressed product source grew by 151 bytes. Three reproducible
gem builds per source snapshot measured 73,728 bytes each.

### Verification and reproduction

- `RUBOCOP_CACHE_ROOT=$PWD/tmp/iterative-audit-rubocop make lint` passed.
  RuboCop checked 155 files, RBS and locale parity passed, and the LOC check
  emitted warnings for three existing files.
- `bundle exec rspec` reported 545 examples, zero failures and four pending.
  The pending examples require the browser revision pinned by Playwright.
- `make bench-gate` passed at 0.1656 s CPU and 0.1690 s wall for 10,000 walks.
  `make bench-stats-gate` passed with 1,600 hits from eight writers, zero lock
  waits and zero write errors.
- Each run of the twelve affected spec files below reported 81 examples and
  zero failures. The runs used `BUNDLE_FROZEN=1` and one of the three
  `BUNDLE_GEMFILE` values `gemfiles/rails72.gemfile`,
  `gemfiles/rails8ruby34.gemfile`, or `gemfiles/rails8ruby4.gemfile`. The first
  two runs used `RBENV_VERSION=3.4.11`. The last run used Ruby 4.0.2.
- `SOURCE_DATE_EPOCH=$(git log -1 --format=%ct) bundle exec ruby benchmarks/package_footprint.rb`
  measured each frozen source snapshot. `git diff --check` passed.

```sh
bundle exec rspec spec/onni/memory_adapter_spec.rb spec/onni/cache_consistency_spec.rb \
  spec/onni/request_preload_spec.rb spec/onni/catalogue_export_spec.rb \
  spec/onni/stats_record_spec.rb spec/onni/middleware/request_lifecycle_spec.rb \
  spec/requests/active_record_adapter_spec.rb spec/requests/gates_for_many_spec.rb \
  spec/requests/stats_purge_active_record_spec.rb spec/requests/admin_features_spec.rb \
  spec/requests/agent_graphql_catalogue_spec.rb spec/requests/visibility_charts_admin_spec.rb
```

The benchmark runner reads Darwin peak RSS through `/usr/bin/time -l`.
Reconstruct `base` from the baseline revision's `lib`, `app` and `sig` trees.
The local `limits-catalogue.json` wraps the catalogue limits from the result
summary under the `limits` key.

```sh
OUT=benchmarks/output/iterative-audit/calibration.json SAMPLES=3 bundle exec ruby benchmarks/pressure_runner.rb calibrate
PRESSURE_PROBE=benchmarks/audit_pressure_probe.rb PROBE=catalogue N=500 SAMPLES=5 PRIMARY=queries BEFORE=benchmarks/output/iterative-audit/base bundle exec ruby benchmarks/pressure_runner.rb compare
PRESSURE_PROBE=benchmarks/audit_pressure_probe.rb PROBE=catalogue N=500 SAMPLES=5 CEILINGS=benchmarks/output/iterative-audit/limits-catalogue.json bundle exec ruby benchmarks/pressure_runner.rb gate
```

## Next

- Include this payload in the 3.0.2 cut
  (`docs/reviews/20261124095700_prepare-3-0-2.md`); commit then `make release`.
- Measure history reads with many unrelated features before deciding whether
  a per-feature index justifies additional write and retention costs.
- Count changed rows and SQL round trips for `observe!` and `park!` before
  deciding whether to replace the full ActiveRecord gate rewrite with a smaller
  write set. Preserve validation, legacy precedence and row locks.

## Source

- [Pressure fixture](../../benchmarks/audit_pressure_probe.rb) and [runner](../../benchmarks/pressure_runner.rb)
- [Purge regression](../../spec/requests/stats_purge_active_record_spec.rb) and [catalogue query regression](../../spec/requests/active_record_adapter_spec.rb)
- [Request cleanup regression](../../spec/onni/middleware/request_lifecycle_spec.rb) and [cache cleanup regression](../../spec/onni/cache_consistency_spec.rb)
- Local result summary and raw samples under `benchmarks/output/iterative-audit/`
