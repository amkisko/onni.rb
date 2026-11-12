# Pressure cooker episode - all feature evaluate paths (accepted)

## Participants

Andrei Makarov (@amkisko)

## Decisions

Machine class: `arm64` (Darwin). Network: `not_in_scope` (memory adapter). Memory probe class: `process_lifetime` (per `benchmarks/binding.md`). Binding: `benchmarks/binding.md`.

Expand the load probe from a single `enabled?` walk to one load unit that evaluates boolean, actor, percentage, group, variant, conditions, and sampled stats paths.

Calibrate: `make bench-calibrate` -> PASS (`order_ok=true`, `distinct_wall=true`) for stages `registry`, `enable`, `boolean`, `actor`, `percentage`, `group`, `variant`, `conditions`, `stats`.

Load (L1): `BENCH_N=2000`, `PRESSURE_MULT=5` -> `N=10_000`, `SAMPLES=5` for propose and prove.

Ceilings file: `benchmarks/ceilings.json`. Propose L1 median x headroom `1.25` for `wall_s`, `cpu_s`, `heap_delta_bytes`. RSS omitted. Re-proposed for the expanded all-features probe (not a silent widen of the old single-path ceilings).

Accept: yes. N = 10 optimize/prove cycles; gate green; no remaining high-confidence first-party candidates above the measured noise floor for the primary series.

## Effects

Calibrate PASS. Matrix L0 wall ~0.033s (N=2000); L1 wall ~0.160s (N=10000); near-linear (~4.8x wall for 5x load).

Proposed ceilings after setup-outside-measure harness change:

- `wall_s` 0.20018125000206055
- `cpu_s` 0.20255000000000006
- `heap_delta_bytes` 1744910.0

Optimize -> prove iterations:

1. Primary `wall_s`. Expand harness to all feature paths; keep fixture prepare outside the timed section. Matrix re-propose. Prove PASS (wall ~0.159s).
2. Primary `wall_s`. No high-confidence product change; hold and re-prove. PASS (~0.160s).
3. Primary `cpu_s`. Hold. PASS (~0.161s).
4. Primary `wall_s`. Hold. PASS (~0.160s).
5. Primary `heap_delta_bytes`. Hold (process_lifetime noise). PASS (~0.158s).
6. Primary `wall_s`. Hold. PASS (~0.163s).
7. Primary `cpu_s`. Hold. PASS (~0.164s).
8. Primary `wall_s`. Hold. PASS (~0.162s).
9. Primary `wall_s`. Hold. PASS (~0.164s).
10. Primary `wall_s`. Final L1 prove `SAMPLES=5`. PASS (~0.162s). Final artifact: `benchmarks/output/20261112145634_load.json`.

Stop: N >= 10, gate green, series inside noise versus ceilings (~20% wall headroom), no further high-confidence first-party candidates for this probe.

## Next

- Keep ceilings tighten-only on slower CI hosts; do not reintroduce RSS gates under `process_lifetime`.
- Optional later episode: ActiveRecord adapter pressure (separate binding; network/storage still local SQLite).

## Source

- `benchmarks/load.rb`, `benchmarks/ceilings.json`, `benchmarks/binding.md`
- Matrix: `benchmarks/output/20261112145530_load.json`
- Prove 1..10 logs under `tmp/pressure/prove_*.log` (local); final prove JSON `benchmarks/output/20261112145634_load.json`
