# Show/skip pressure episode binding

Historical episode for the transitional show/skip implementation. Raw results
and ceilings remain frozen. Current ready/park/visible verification is recorded
in docs/issues/20261113091112_ready-park-visible-terminology.md and
benchmarks/terminology_v1_results.json. Current commands use the renamed API.

The seven-path evaluation walk is the end-to-end probe. The named component
probes isolate observed first-party costs. CPU seconds are the energy proxy;
joules and co-location effects are not measured. All fixtures are local, so
network transfer is not_in_scope.

## Commands

```sh
OUT=benchmarks/output/show_skip_calibration.json bundle exec ruby benchmarks/pressure_runner.rb calibrate
SNAPSHOT=tmp/pressure-show-skip/before bundle exec ruby benchmarks/pressure_runner.rb snapshot
PROBE=all N=10000 OUT=benchmarks/output/show_skip_L0.json bundle exec ruby benchmarks/pressure_runner.rb measure
PROBE=all N=100000 OUT=benchmarks/output/show_skip_L1.json bundle exec ruby benchmarks/pressure_runner.rb measure
PROBE=variant PRIMARY=allocated_objects NOISE=0.0001 BEFORE=tmp/pressure-show-skip/before OUT=benchmarks/output/compare.json bundle exec ruby benchmarks/pressure_runner.rb compare
CEILINGS=benchmarks/show_skip_pressure_ceilings.json PROBE=all OUT=benchmarks/output/gate.json bundle exec ruby benchmarks/pressure_runner.rb gate
```

SAMPLES defaults to five and must be at least three. Comparisons alternate the
before/after order. Each child loads one immutable source snapshot. Source
digests are checked again at completion. The native Darwin time utility provides
process-lifetime peak RSS. A missing or zero memory sample fails the run.
The native utility needs permission to read its resource counters in restricted
environments. This runner currently supports Darwin, and rejects other hosts.

## Load and fixtures

Raise only evaluation count: L0 10000, L1 100000, concurrency one, warmup 1000.
The all probe performs seven evaluations per walk using the existing load fixture
and one deterministic actor. The original load.rb gate additionally exercises
the rotating-actor fixture. Group legacy probes hold five group rows, matching
the last registered group. The ignored probe holds 100 unmatched names.

Component probes are global, conditions, group, legacy_group, legacy_power,
variant, ignored, sampler, stats_disabled, buffer, memory_write, cache, and
gate_write. Every child checks powered boolean, percentage, and variant outcomes.
Buffer and memory-write probes also require exact recorded totals.

Stage latency fields are p95 of 20 batches of 100 calls, recorded separately
from aggregate wall/CPU. They are batch latency, not individual-call p95.
Calibration separates three known sleep-stage p95 values from aggregate time,
observes 20000 allocations, and touches 32 MiB to validate the RSS meter.

## Metrics and decisions

Use median CPU, wall time, and allocated-object count. Use maximum process peak
RSS and byte counts. CPU directional claims need a 3% median improvement; the
allocation floor is 0.01%. Same-source A/A measurements establish the noise check.
An allocation-primary change also needs CPU ratio <=1.10 and RSS ratio <=1.15.

The episode proposes CPU, wall, and allocation limits at 0.85 times initial L1
medians. RSS and stats bytes use 1.15 times initial maxima. Uncompressed product
source bytes use 1.05 times baseline bytes. Never raise limits within the episode.
Promote only after at least ten counted optimize/prove decisions, contract checks,
and an independent end-to-end gate against the unchanged proposal.

store_bytes is serialized stats payload size, not filesystem usage or Ruby heap.
cache_accounted_bytes is the configured MemoryStore's eviction-accounting size.
source_bytes covers lib, app, and sig uncompressed. Gem package bytes are measured
separately. Temporary YAML input is fixed-size; no growing persistent fixture is
used by the evaluation probes. Sample SQLite fixture bytes separately; the
sibling probe's stock storage-delta fields are not used as storage evidence.

Correctness fixes may have explicit measured costs. Record cache-generation
checks and gate-write ownership costs separately; do not call them speedups.
Do not run correctness suites or other load generators concurrently with proves.

## Evidence and promotion

The tracked results file is benchmarks/show_skip_pressure_results.json. It keeps
calibration, raw samples, source digests, decisions, failures, and the final gate.
It excludes hostnames, absolute paths, cache namespace values, and actor IDs.
The ceiling file is benchmarks/show_skip_pressure_ceilings.json. Copy the
unchanged proposal into that file only after the evidence bundle's gate passes
and the counted decisions total at least ten. Check source digest equality before
writing. Later results never replace evidence of an earlier failed gate.
