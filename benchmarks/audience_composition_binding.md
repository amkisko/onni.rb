# Audience composition comparison

One-change comparison for RFC-0005. Existing ceilings remain unchanged.
Evidence is in audience_*_results.json. The before_global_fast_path result keeps
an earlier aggregate measurement that exceeded CPU and wall limits, before the
everyone-only path was shortened. It is not final implementation evidence.

## Sources and fixtures

Before: commit de1ff4e11cb4d62da4760fdb6e9b397d9f682546. After: the working tree
identified by each result's source digest. Each sample starts a fresh Ruby
process and memory adapter. CPU, wall time, and allocations exclude setup and
1000 warmup calls. Native Darwin time supplies process-lifetime peak RSS.
Use three alternating before/after samples per series, 100000 calls per sample.

The same audience_probe.rb loads both source trees and adapts only fixture
setup to their supported APIs. Runtime calls compare equivalent passing
expressions. The percentage feature key and actor identity stay the same.
The actor passes the 25% bucket and group predicate. No callbacks perform IO.

- global: actor-free everyone visibility, one call in each implementation.
- group: two include groups, matching the second, one call in each.
- percentage: global level 25, one call in each.
- composed_typical: groups and percentage; two former typed flags versus one
  composed flag.
- composed: include groups and actor, exclude groups and actor, and percentage;
  five former typed flags versus one composed flag. Exclude matches reject in
  both expressions; this fixture passes every clause to exercise the full path.
- all: the existing seven-path pressure_probe.rb and each source tree's matching
  load fixture, including conditions, variants, and feature statistics.

## Commands

Run serially without correctness suites or another load generator:

```sh
mkdir -p tmp/audience-before
git archive de1ff4e11cb4d62da4760fdb6e9b397d9f682546 | tar -x -C tmp/audience-before
for audience_probe in global group percentage composed_typical composed; do
  PROBE="$audience_probe" N=100000 SAMPLES=3 PRESSURE_PROBE=benchmarks/audience_probe.rb BEFORE=tmp/audience-before OUT="benchmarks/audience_${audience_probe}_results.json" bundle exec ruby benchmarks/pressure_runner.rb compare || exit 1
done
PROBE=all N=100000 SAMPLES=3 BEFORE=tmp/audience-before OUT=benchmarks/audience_all_results.json bundle exec ruby benchmarks/pressure_runner.rb compare
```

The restricted host initially denied native time's resource-counter access;
final measurements ran with that OS read permitted. An incomplete sample is
not a zero-memory result.

## Units and limits

CPU and wall use medians; allocations use the median; RSS and byte counts use
maxima. For audience_probe, store_bytes means serialized gate rows. For the all
probe, it means serialized statistics rows. Those storage quantities cannot be
compared across probe kinds. Neither is filesystem usage or Ruby heap size.
source_bytes covers uncompressed lib, app, and sig, not the packaged gem.

Compare all against show_skip_pressure_ceilings.json at N=100000. That historical
file defines aggregate limits, not separate group or percentage ceilings.
Component series provide before/after evidence, not new absolute limits.
The source-size ceiling was already exceeded by the before tree. No ceiling is
raised here. These single-actor synthetic results do not estimate callback IO,
ActiveRecord throughput, production p95, energy in joules, or large-list scale.
