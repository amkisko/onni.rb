# Evaluation statistics and runtime definitions

One-change comparison for RFC-0006 and RFC-0007 against the completed audience
composition tree. No dependency, schema, or ceiling changes.

## Sources

The before snapshot reproduces the product digest frozen by the previous
audience validation: 7889ec6e4b3e94ff6694905bc7f977cfdb6f373c016e6e0884590f7b20598da4.
The after product digest is recorded in each result. Paths and bytes under
lib, app, and sig produce the digest; benchmark fixtures have separate digests.
Historical audience comparison files describe their recorded source, not this
later implementation. The audience matrix proof is rerun for this product.

## Commands

Run each command sequentially, with no concurrent tests or load. Native Darwin
/usr/bin/time -l measures process peak RSS. Three alternating before/after
samples use Ruby 4.0.2 on arm64-darwin24. Setup and 1000 warmup calls are outside
the timed section. CPU and wall use the median; RSS and stored/source bytes use
the largest sample. CPU is an energy proxy, not measured power.

```sh
PROBE=all N=100000 SAMPLES=3 BEFORE=tmp/evaluation-stats-before OUT=benchmarks/evaluation_stats_all_results.json bundle exec ruby benchmarks/pressure_runner.rb compare
PROBE=pending N=100000 SAMPLES=3 BEFORE=tmp/evaluation-stats-before OUT=benchmarks/evaluation_stats_pending_results.json bundle exec ruby benchmarks/pressure_runner.rb compare
PROBE=parked N=100000 SAMPLES=3 BEFORE=tmp/evaluation-stats-before OUT=benchmarks/evaluation_stats_parked_results.json bundle exec ruby benchmarks/pressure_runner.rb compare
make bench-gate
```

The ignored before snapshot is local reproduction material; its digest binds
the comparison to the previous validation. The committed result files preserve
raw samples and source/harness digests without local machine identifiers.

## Work and costs

All runs the existing seven-path walk with its explicit 0.1 sample rate and
unbuffered memory adapter. It is a workload setting, not the new install default.
Pending and parked run one known off-state visible? per operation. Previously
those calls returned without a write; now they use rate 1.0 and record every
skip. The after probe checks count + 1001 skips including warmup and its final
validation call. These series compare changed work, not equivalent output.

- All: CPU 1.480253 -> 1.696015 s (+14.6%); wall 1.481327 -> 1.697321 s.
  Allocations remain 3919145. Peak RSS 42352640 -> 41484288 bytes.
  Serialized stats remain 664 bytes.
- Pending: CPU 0.057524 -> 0.200159 s; wall 0.057596 -> 0.200444 s.
  Allocations 200009 -> 800009. Peak RSS 42041344 -> 42188800 bytes.
  Serialized stats 2 -> 96 bytes: an empty result becomes one hourly bucket.
- Parked: CPU 0.071680 -> 0.219556 s; wall 0.071779 -> 0.219804 s.
  Allocations 200009 -> 800009. Peak RSS 43122688 -> 41795584 bytes.
  Serialized stats 2 -> 96 bytes.
- Product source bytes: 106094 -> 114099 (+7.5%). This is source size, not a
  packaged gem or deployed process image size.

The expensive unit is one accepted adapter counter update. Unbuffered known
off-state calls now add one update each; inline false or a veto adds none.
Buffering coalesces accepted updates by feature/hour until request cleanup or
explicit flush. An adapter supporting batch writes receives one batch per
flush. No new actor or group counter dimensions exist.

The existing rotating-actor delivery gate passed 10000 all-feature walks:
CPU 0.173522 s <= 0.210755 s and wall 0.171746 s <= 0.20896875 s.
Heap delta 194328 bytes <= 5358608.75 bytes. Its zero RSS fields mean unavailable,
not zero memory use. Native RSS is supplied by the comparison files above.
This delivery gate and the historical 100000-walk aggregate ceilings are
different contracts. The earlier aggregate timing/source-size concerns remain
open; no claim of a performance improvement or a production database budget.

## Lifetime and surface

YAML plus committed adapter gates/counters remain authoritative for declared
features. Parsed snapshots, request preloads, and application cache entries
rebuild from those sources; cache representation advances to v4. In-process
programmatic definitions survive cache, adapter, and registry resets, but are
lost at process exit and must be recreated by host initialization in each
worker. The memory adapter remains ephemeral. No new UI surface was added;
README and RFCs document the controls. The earlier admin visual assessment
continues to describe only the audience editor.
