# Pressure binding - onni

## Measure

```sh
SCENARIO=gate bundle exec ruby benchmarks/load.rb
# or: make bench-gate
# before/after without rewriting ceilings:
# SCENARIO=observe BENCH_LABEL=label BENCH_PRELOAD=1 BENCH_STATS_BUFFER=1 bundle exec ruby benchmarks/load.rb
```

## Self-test (calibrate)

```sh
SCENARIO=calibrate bundle exec ruby benchmarks/load.rb
# or: make bench-calibrate
```

Distinct stages: `registry`, `show`, `boolean`, `actor`, `percentage`, `group`, `variant`, `conditions`, `stats`. Fail if stage order or wall separation collapses.

## Ceilings

`benchmarks/ceilings.json` - propose from L1 median x headroom `1.25` for `wall_s`, `cpu_s`, `heap_delta_bytes`. RSS omitted (`process_lifetime` noise).

## Load axis

- `N` - number of all-features walks per sample (each walk evaluates boolean, actor, percentage, group, variant, conditions, and stats-sample paths once)
- L0 default `N=2_000` (`BENCH_N`)
- L1 default `N=10_000` (`PRESSURE_MULT` ~5)
- Fixture: in-process memory adapter, `concurrency=:mutex`, YAML registry with seven flags

## Samples

- `SAMPLES` default `3` (gate / propose / write); use `>=5` for prove when tightening

## Episode iterations

- `N_ITER` default `10` (optimize -> prove)

## Propose basis

- timing / heap: L1 median x headroom `1.25`
- `TARGET_FACTOR` reserved for later tighten-only passes
- do not gate on RSS deltas under `process_lifetime`

## Memory probe class

`process_lifetime`

## Network

`not_in_scope` (in-process memory adapter only)

Ready/park/visible verification keeps the same seven evaluation paths with
explicit YAML types. The visible stage replaces the transitional show label;
counts use shown_count/skip_count. Existing limits remain unchanged unless a
separate pressure episode accepts a tighter proposal.
Use the larger observed heap delta across calibration and a fresh gate run, multiplied
by 1.25, because the wall-time median alone does not bound GC-dependent heap deltas.
