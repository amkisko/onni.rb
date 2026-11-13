# Pressure benchmark show/skip evaluation

## Participants

Andrei Makarov (@amkisko), the operator named in the implementation plan.

## Decisions

Run at least ten optimize/prove cycles using pressure-benchmarking and
engineering-audit. Preserve the current uncommitted show/skip implementation.
Each cycle names one primary probe and series before editing. Retain a fix only
when its contract checks pass and its primary metric improves beyond its stated
noise floor; record rejected attempts too. Do not force a cheaper claim per cycle.

Use five raw samples per revision, alternate before/after source snapshots, and
raise evaluations from L0 10000 to L1 100000 without changing concurrency. CPU
seconds are the energy proxy. Memory is process-lifetime peak RSS, never stage
RSS. Local memory and SQLite probes have no network transfer. No dependency or
runtime upgrade is authorized by this episode.

The prior RSS probe reports zero under this sandbox. Calibrate a native resource
meter against known allocation and sleep fixtures before any new baseline. Keep
hostnames, absolute paths, and actor identifiers out of saved measurement data.

## Effects

Calibration passed five process-isolated samples. Native peak RSS ranged from
73629696 to 75333632 bytes for the 32 MiB allocation fixture. Separate sleep
stage p95 and aggregate CPU/wall fields passed. Same-source A/A medians differed
by 0.3% CPU and zero allocated objects. Use a 3% CPU improvement floor and a
0.01% allocation improvement floor. RSS remains a process-lifetime budget with
15% headroom, not a claimed per-stage gain. Do not raise accepted ceilings.

Cycle 1 primary: global.allocated_objects. Remove the duplicate known?/definition
registry lookup in show?; a single missing definition still fails closed. Keep
all other evaluation paths unchanged for this prove.

Initial L1 is 100000 walks: median CPU 1.803774s, wall 1.808119s, and
8089001 allocated objects. Propose 15% tighter CPU, wall, and allocation ceilings;
memory and byte ceilings use the named headroom in the proposal artifact. The
proposal is not promoted until ten cycles and the final end-to-end gate pass.
Treat cycle 1 as a pilot because it preceded the written ceiling proposal. Run
at least ten further counted cycles after tightening. For allocation-primary
cycles, reject more than 10% CPU regression or 15% peak-RSS regression even if
allocations improve; do not claim CPU improvement below the 3% floor.

Cycle 2 primary: global.allocated_objects. Move the no-actor condition return
before building an empty condition array. The definition lookup and actor
condition contract remain unchanged.

Cycle 3 primary: conditions.allocated_objects. Avoid Array(nil) when an actor
has no configured conditions. Preserve non-nil scalar handling and fail-closed
unknown condition tokens.

Cycle 4 primary: legacy_group.allocated_objects. The legacy fixture has five
stored group gates and matches the last registered group. Compute the override
key once before the scan instead of interpolating a new string for every gate.
This measures the supported legacy row shape, not the compact override shape.

Cycle 5 primary: variant.allocated_objects. JSON object keys are already strings
and the parsed hash is owned by this read. Coerce its weights in place instead
of allocating two more hashes. YAML defaults keep their copying path; callers
still receive independent values and legacy string weights still normalize.

Cycle 6 primary: sampler.cpu_s. The configured sample rate is already coerced by
its setter. Coerce only a non-nil custom sampler result, keeping nil fallback and
custom string-rate behavior. Require at least 3% CPU improvement.

Cycle 7 primary: ignored.allocated_objects. With 100 configured ignored names,
convert the evaluated feature name once, not once per comparison. An empty ignore
list must still avoid this conversion and must not add work to the common path.

Cycle 8 primary: legacy_power.allocated_objects. Reuse the immutable legacy
type-to-gate mapping instead of allocating it per legacy power check. Keep
legacy boolean and audience-type matching behavior intact.

Cycle 9 primary: stats_disabled.cpu_s. Return from Stats.record before dispatching
to the sampler when the master switch is false. Keep the sampler's independent
check for direct callers. The end-to-end gate must include enabled stats because
this adds a guard to that path. Require at least 3% disabled-path CPU improvement.

Cycle 10 primary: buffer.cpu_s. Publish the fiber-local buffer only when it is
created; subsequent additions update the already-published hash. Flush/reset and
coalesced counts must remain unchanged. Require at least 3% CPU improvement.

Cycle 11 primary: memory_write.cpu_s. Replace formatted-hour string bucket keys
with an owned feature string and integer UTC hour. Update read, purge, and
overview consumers together. This also prevents a feature-name delimiter from
changing bucket identity. Preserve caller-string ownership and hour boundaries.

Cycle 12 primary: variant.allocated_objects. Apply the single-definition lookup
to the remaining variant evaluation and hard-off inspection paths. Missing
definitions must still fail closed; this completes the repeated-lookup finding.

Cycle 13 primary: memory_write.allocated_objects. Cycle 11 improved CPU but
allocated one extra object per symbol-key write. Symbol#to_s already creates an
owned string; freeze that result directly. Other key objects must still be
copied so a caller cannot alter bucket identity or have its own string frozen.

The bounded audit also reproduced four failing regression examples: a 50-flag
admin index issued 50 gate SELECTs; a valid summed batch lost 1000016 weighted
counts; a stats flush failure replaced a successful HTTP result; the same
failure masked the application's original exception. Fix the query budget with
the existing bounded registry preload, preserve aggregate weights, and make
request-end telemetry failure best-effort while always clearing scratch state.
Explicit flush_stats! remains observable to its caller. Do not retry ambiguous
stats writes. No auth, feature-evaluation, or chart-copy contract changes.

The first absolute end-to-end prove failed CPU/wall despite a 15.4% paired CPU
gain and an 18.5% allocation gain. Keep the proposed ceilings unchanged.
Cycle 14 primary: all.allocated_objects. Remove repeated gate-row copying from
memory-backed evaluation with immutable internal snapshots. Public adapter reads
remain independent mutable copies; writes publish a new frozen snapshot. This
also fixes mutation of stored gates through caller-owned value strings. Custom
adapters keep the existing gates_for fallback; the snapshot capability is optional.

The cache race reproduction confirmed that a delayed fill could restore old gates
after skip! had committed and invalidated the entry. Add a per-live-adapter
namespace and per-feature generation fence. The short mutex protects metadata,
not cache or adapter IO. Old fills write an obsolete generation. Weak adapter
ownership releases metadata after adapter collection. Measure the warm-cache
cost separately; this correctness repair is not counted as a speedup cycle.
Request preloads remain request snapshots, and other processes' writes are not
made globally synchronous by this local fence.

Preserve failed absolute proves in the evidence bundle. The coverage-worker run
overlapped the last comparison; rerun the final prove alone after workers exit.
Do not promote a contended failure or widen a ceiling to hide it.

The standalone final gate passed unchanged limits. The write-side trade-off
probe then measured 12.7% more gate-write CPU and 29.4% more allocations from
owned immutable snapshots. Cycle 15 primary: gate_write.allocated_objects.
Avoid copying an already-owned working array and already-frozen field strings.
Keep mutable-input isolation, snapshot independence, and aborted-write isolation.

All fifteen measured cycles improve their declared primary series. Cycle 1 is
the pilot; cycles 2 through 15 count toward the fourteen accepted decisions.
Cycle 11 temporarily adds allocations while improving its CPU primary; cycle 13
removes that allocation regression. Cycle 14 first failed its mutation contract
with FrozenError; repair the working-copy handling before accepting its prove.

Final five-sample paired comparison: CPU 1.838208 -> 1.398583s (-23.9%),
allocations 8089001 -> 4489001 (-44.5%), maximum RSS 41631744 -> 41910272 bytes.
The independent final gate passes every unchanged proposed limit. Source bytes
grow 2.3%; three deterministic gem builds grow 41984 -> 43008 compressed bytes.
Final gate-write trade-off is +7.0% CPU and +11.8% allocations against the
pre-snapshot build; initial-to-final warm-cache CPU is within the 3% noise floor.

Full RSpec: 202 examples, zero failures. Lint: 88 files clean, RBS valid, locales
in parity, two existing LOC warnings. Five coverage workers pass; clean coverage
is 1238/1271 repository lines. Move aside one stale fragment before the final
five-fragment merge. Stock evaluation and SQLite eight-writer gates pass existing
limits. The 1/2/4/8/16-writer ladder has no lock/write errors in retained rows.
Exact commands and raw measured samples are in the evidence bundle.

## Next

Stop the episode after fourteen counted improvements and the independent gate;
the unchanged proposal is promoted and its separate verification passes.
Review before release. Cache cross-process
consistency, cold-miss coalescing, high-cardinality metadata, and sustained load
remain explicit limits, not claims resolved by this local benchmark.

## Source

- [Implementation issue](20261113060000_show-skip-typed-flags.md)
- [Evaluation binding](../../benchmarks/binding.md)
- [Stats binding](../../benchmarks/stats_write_binding.md)
- [Pressure episode binding](../../benchmarks/show_skip_pressure_binding.md)
- [Raw evidence and commands](../../benchmarks/show_skip_pressure_results.json)
- [Engineering audit](../reviews/20261113090500_pressure-engineering-audit.md)
- [Engineering changelog](../changelogs/20261113090500_pressure-show-skip-evaluation.md)
