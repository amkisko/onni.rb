# Pressure cooker episode - ActiveRecord stats write locks

## Participants

Andrei Makarov (@amkisko)

## Decisions

Separate episode from the memory all-features probe. Primary question: at what concurrent write load does `onni_feature_stat_buckets` upsert start pressuring (lock wait / non-linear wall / busy timeout), and which first-party levers reduce that for high request volume.

Machine class: `arm64` (Darwin). Dialect: SQLite file DB with WAL (default). PostgreSQL row-lock sibling not measured this episode (local socket blocked in the runner).

Load axis: concurrent writers `W` against one hot hour bucket. Fixed `OPS=200` upserts per writer. Modes: `direct` (adapter upsert per hit), `buffer` (coalesce + flush), `sample` (`stats_sample_rate=0.1`).

Binding: `benchmarks/stats_write_binding.md`. Ceilings: `benchmarks/stats_write_ceilings.json` (L1 direct W=8 median x 1.25).

Memory probe class: `process_lifetime`. Network: `not_in_scope`. Storage: probe DB under `tmp/stats_write_bench/`.

Primary series: `wall_s` under concurrent upsert. Side series: `ops_per_s`, `lock_waits`, `write_errors`.

Accept for episode goals (inflection + host guidance): yes. Product code path unchanged; recommendation is existing `stats_buffer` / sample / ignore. Direct-path L1 ceilings written for gate regression. Cooker N=10 prove cycles used buffer mode at W=8 (the high-volume path).

## Effects

Calibrate: `SCENARIO=calibrate` -> PASS (`order_ok=true`, `distinct_wall=true`) for stages `setup`, `single_write`, `concurrent_wait`, `buffer_flush`, `lock_busy`.

Ladder (WAL, timeout 5000ms, SAMPLES=3, OPS=200), median walls:

- W=1 direct 0.0358s (~5583 ops/s); buffer 0.0028s; sample 0.0060s; lock_waits=0
- W=2 direct 0.0711s (~5630 ops/s); buffer 0.0044s; sample 0.0094s; lock_waits=0
- W=4 direct 0.1433s (~5581 ops/s); buffer 0.0047s; sample 0.0181s; lock_waits=0
- W=8 direct 0.2752s (~5814 ops/s); buffer 0.0108s; sample 0.0327s; lock_waits=0
- W=16 direct 0.5750s (~5565 ops/s); buffer 0.0234s; sample 0.0637s; lock_waits=0

Inflection: pressure starts at W=2. Direct wall scales about linearly with W; direct ops/s stays flat (~5.5k-5.8k). That is write-lock serialization on the hot hour row, not parallel scaling. With default busy timeout, failures are rare; latency queue bloat is the symptom. W=32 with `DB_TIMEOUT_MS=50` hung the stress loop (queue wait), so short timeouts turn bloat into stalls/errors.

Matrix L0 W=1 / L1 W=8 direct: baseline wall ~0.0347s; pressure ~0.2736s. Proposed ceilings (x1.25): `wall_s` ~0.342, `cpu_s` ~0.347, `heap_delta_bytes` ~9.1e6, `lock_waits` 0, `write_errors` 0.

Gate direct W=8: PASS (wall ~0.270s).

Optimize/prove (primary `wall_s`, high-volume path = buffer):

1. Document concurrent write guidance in README; binding + probe. Prove buffer W=8 PASS (~0.012s).
2-10. Hold buffer path; re-prove W=8 SAMPLES=3. All PASS (wall ~0.011-0.013s, ~123k-140k ops/s, lock_waits=0).

Stop: inflection measured; N>=10 buffer proves green; no high-confidence first-party adapter rewrite above noise (buffer already coalesces to one upsert per writer flush). PostgreSQL sibling deferred.

## Next

- Done in follow-up audit: RequestLifecycle middleware, `request_preload`, batch `upsert_all` (`docs/reviews/20261113053059_iterative-engineering-audit-stats-lifecycle.md`).
- Optional: PostgreSQL hot-row sibling with `pg_stat_activity` wait events when a local probe DB is available.
- Optional later: process-wide async rollup only if buffer+sample still saturates a host under production concurrency.
- Keep direct L1 gate as worst-case regression; do not treat buffer walls as the direct ceiling.

## Source

- `benchmarks/stats_write.rb`, `benchmarks/stats_write_binding.md`, `benchmarks/stats_write_ceilings.json`
- Ladder: `benchmarks/output/20261113051612_stats_write.json`
- Matrix: `benchmarks/output/20261113052020_stats_write.json`
- Gate: `benchmarks/output/20261113052148_stats_write.json`
- Prior memory episode: `docs/issues/20261112145330_pressure-all-features-episode.md`
- Adapter: `lib/onni/adapters/active_record.rb`; buffer: `lib/onni/stats/buffer.rb`
