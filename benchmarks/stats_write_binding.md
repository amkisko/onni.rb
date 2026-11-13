# Pressure binding - onni stats write locks

## Measure

```sh
SCENARIO=ladder bundle exec ruby benchmarks/stats_write.rb
SCENARIO=matrix WRITERS=1 WRITERS_L1=8 OPS=200 SAMPLES=3 bundle exec ruby benchmarks/stats_write.rb
SCENARIO=observe MODE=buffer WRITERS=8 OPS=200 bundle exec ruby benchmarks/stats_write.rb
SCENARIO=gate WRITERS_L1=8 OPS=200 bundle exec ruby benchmarks/stats_write.rb
```

## Self-test (calibrate)

```sh
SCENARIO=calibrate bundle exec ruby benchmarks/stats_write.rb
```

Distinct stages: `setup`, `single_write`, `concurrent_wait`, `buffer_flush`, `lock_busy`. Fail if stage order or wall separation collapses.

## Ceilings

`benchmarks/stats_write_ceilings.json` - propose from L1 median x headroom `1.25` for `wall_s`, `cpu_s`, `heap_delta_bytes`. Gate also requires `lock_waits=0` and `write_errors=0` when written. RSS omitted (`process_lifetime` noise).

## Load axis

- `W` - concurrent writers against one hot hour bucket (`feature_key` + current hour)
- `OPS` - upserts (or buffered records) per writer
- L0 default `W=1`, L1 default `W=8`, `OPS=200`
- Ladder default `W` in `1,2,4,8,16` crossed with modes `direct`, `buffer`, `sample`
- Fixture: ActiveRecord + SQLite file (`benchmarks/tmp/stats_write_bench/`), WAL, pool 32, busy timeout 5000ms

## Samples

- `SAMPLES` default `3` (gate / propose / write); use `>=5` for prove when tightening

## Episode iterations

- `N_ITER` default `10` (optimize -> prove)

## Propose basis

- timing / heap: L1 median x headroom `1.25`
- contention: zero `lock_waits` / `write_errors` at accepted L1 for buffered/sample modes when those are the product recommendation
- do not gate on RSS deltas under `process_lifetime`

## Memory probe class

`process_lifetime`

## Network

`not_in_scope` (local SQLite file)

## Storage

Local SQLite file growth is in scope for the probe DB path under `benchmarks/tmp/`.

Ready/park/visible verification keeps direct L1 at eight writers and 200 evaluations per
writer. Stored counters are shown_count/skip_count; zero lock waits and write errors
remain required.
