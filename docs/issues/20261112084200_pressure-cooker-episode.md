# Pressure cooker episode - onni enabled? path (accepted)

## Participants

Andrei Makarov (@amkisko)

## Decisions

Machine class: `arm64` (Darwin). Network: `not_in_scope` (memory adapter). Memory probe class: `process_lifetime` (per `benchmarks/binding.md`). Binding: `benchmarks/binding.md`.

Calibrate: `make bench-calibrate` (`SCENARIO=calibrate`) -> PASS (`order_ok=true`, `distinct_wall=true`).

Load (L1): `BENCH_N=2000`, `PRESSURE_MULT=5` -> `N=10_000`, `SAMPLES=5` for prove.

Ceilings file: `benchmarks/ceilings.json`. Propose L1 median x headroom `1.25` for `wall_s`, `cpu_s`, `heap_delta_bytes`. RSS omitted (process-lifetime noise). Written during matrix; not widened during optimize cycles.

Accept: yes. N at least 10 optimize/prove cycles; gate green; ceilings tighten-ready without RSS.

## Effects

Final gate prove path: `benchmarks/output/20261112084200_load.json`. Pass: true (cycles 1-10 all PASS). Representative median vs ceiling: wall ~0.011s <= ~0.0134s; cpu ~0.013s <= ~0.0162s; heap_delta ~1.0MiB <= ~1.3MiB.

Optimize -> prove iterations:

1. Primary `wall_s` / correctness. Fail closed on past `expires_at` in `Store#evaluate`. Prove PASS.
2. Primary `wall_s`. Parse `expires_at_time` once in `Registry.load_config`. Prove PASS.
3. Primary `wall_s`. `Group.known?` O(1); Conditions stop linear `names` scan. Prove PASS.
4. Primary `heap_delta_bytes`. Memory `EMPTY_GATES` frozen empty; map-dup non-empty gates. Prove PASS.
5. Primary `wall_s`. Pass definition into `Conditions.met?` (skip second registry dig). Prove PASS.
6. Primary `heap_delta_bytes`. Frozen `CACHE_KEY_PREFIX` on Store cache keys. Prove PASS.
7. Primary `wall_s`. Bench harness cleaned; stats disabled; memory adapter only. Prove PASS.
8. Primary ceilings. Matrix re-propose L1 x 1.25; omit RSS from gate targets. Prove PASS.
9. Primary `cpu_s`. Re-gate after expiry + conditions path changes. Prove PASS.
10. Primary `wall_s`. Final L1 prove `SAMPLES=5`. Prove PASS.

Tests: `bundle exec rspec` - 13 examples, 0 failures (includes expired-flag example).

## Next

- Keep ceilings tighten-only on slower CI hosts; do not reintroduce RSS gates under `process_lifetime`.

## Source

- `lib/onni/store.rb` - expiry + evaluate
- `lib/onni/registry.rb` - `expires_at_time`
- `lib/onni/group.rb` / `lib/onni/conditions.rb` - O(1) group match
- `lib/onni/adapters/memory.rb` - empty/non-empty gates isolation
- `benchmarks/load.rb`, `benchmarks/ceilings.json`, `benchmarks/binding.md`
- `Makefile` - `bench-calibrate`, `bench-matrix`, `bench-gate`
- Engineering audit: `docs/reviews/20261112084200_engineering-audit.md`
