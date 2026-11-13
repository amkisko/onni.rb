# Iterative engineering audit of adapter contracts

## Participants

Andrei Makarov (@amkisko), confirmed in this session.

## Decisions

The [live work record](../issues/20261113104213_iterative-audit-adapter-contracts.md)
owns the scope, acceptance conditions, and diagnostic budgets. Four rounds
cover import -> gates, buffer -> individual adapter writes, history -> caller,
then re-audit of the import source boundary. No dependency changes were made
for these repairs. Concurrent version/release edits were left in place.

Run core, performance, resource/budget, contracts, lineage, privacy,
trace/identification, cache lifecycle, and scoped security checks. Boundary and
control covers mutation ordering, explicit parked power, buffer flush, and
history period interpretation. There are no physical actuators. This is a local
engineering episode, not a deployment or repository-wide security assessment.

## Effects

### Confirmed baseline defects, ranked

1. A1. Severity medium; confidence high; evidence observed; category contract;
   stage import -> gates. Location: Migrator::Importer#gate_field.
   A symbol-keyed false value was read as missing. Import skipped the park
   command and left an already-ready feature ready. Smallest fix: read the
   indexed value once and fall back to the String field only when it is nil.
   The new failing regression now proves explicit parked power and invisibility.
2. A3. Severity medium; confidence high; evidence observed; category count
   conservation; stage buffer -> adapter. Location: Stats::Buffer.flush!.
   Without record_stats_batch, a summed count was sent as one bounded sample.
   The regression requested 2000007 per side and stored 1000000 per side.
   Smallest fix: split each aggregate into writes no larger than MAX_WEIGHT.
   The batch-capable path stays unchanged. The regression now conserves both
   sums, returns the same flushed-feature count, and leaves no second flush.
3. A2. Severity medium; confidence high; evidence observed; category contract;
   stage import -> evaluation. Location: Migrator::Importer#write_gate.
   Validation interpreted 0x32 as 50 while storage later evaluated it as 0.
   Smallest fix: serialize the same Integer interpretation before storing the
   percentage. Regressions cover hexadecimal, underscore, leading-zero, and
   numeric inputs. They compare the resulting public level to validation.
4. A5. Severity low; confidence high; evidence observed; category contract;
   stage history -> caller. Location: Memory::Statistics#stats_for.
   A day query returned hour buckets labeled day; ActiveRecord filters period.
   Smallest fix: return no rows for unsupported periods. The regression proves
   that the rejected query does not remove the stored hourly count.
5. A4. Severity low; confidence high; evidence observed; category ordering;
   stage history -> caller. Location: Memory::Statistics#stats_for.
   Backdated writes returned hours 12, 10, 11 while ActiveRecord orders by time.
   Smallest fix: sort the independent returned rows after releasing the lock.
   The regression proves chronological order and count conservation.

### Iteration evidence

- Baseline `bundle exec rspec`: 215 examples, zero failures.
- Round 1: `bundle exec rspec spec/onni/migrator_importer_spec.rb`: 8 examples,
  2 failures before repair, then zero failures.
- Round 2: `bundle exec rspec spec/onni/stats_buffer_spec.rb`: 3 examples,
  1 failure before repair. Buffer, record, and ActiveRecord batch checks then
  pass 12 examples using `bundle exec rspec spec/onni/stats_buffer_spec.rb
  spec/onni/stats_record_spec.rb spec/onni/adapters/active_record_stats_batch_spec.rb`.
- Round 3: `bundle exec rspec spec/onni/memory_adapter_spec.rb`: 10 examples,
  2 failures before repair. Memory, chart, and ActiveRecord adapter checks pass
  27 examples using `bundle exec rspec spec/onni/memory_adapter_spec.rb
  spec/onni/visibility_chart_spec.rb spec/requests/active_record_adapter_spec.rb`.
- Round 4 rejects an intermediate Hash#fetch requirement with a failing indexed
  Struct-row regression. Final `bundle exec rspec spec/onni/migrator_importer_spec.rb`:
  9 examples, zero failures. Only indexed field reads remain in the implementation.

### Measured costs

The [evidence bundle](../../benchmarks/engineering_audit_results.json) retains
exact commands, source/probe digests, raw samples, correctness oracles, and
machine-checked budgets. Five alternating isolated child processes per side
measure 100000 operations, except history uses 10000 queries over 2400 buckets.
There are 100 unmeasured warmup operations per sample. Machine class:
arm64-darwin24, Ruby 4.0.2. Native RSS calibration uses a touched 32 MiB fixture.

Median CPU changes: ordinary import +4.9%, indexed-row import +4.5%, small
fallback flush +6.0%, large fallback flush +68.7%, and history query +3.4%.
The large fallback now performs four writes instead of two to retain every
count. Its allocations rise 60%; ordinary import allocations rise 6.25%.
There is no speedup or lower-memory claim.

The malformed import fixture costs +27.9% CPU, exceeding the unchanged 25%
diagnostic allowance. Baseline omitted the false-valued write and returned the
wrong percentage. Retain the correctness repair and record the budget miss;
the ordinary and indexed input fixtures pass that allowance.

The final unchanged absolute gate passes: median CPU 1.426977s <= 1.5332079s;
wall 1.429412s <= 1.5369011500442866s; allocations 4489001 <= 6875650.85;
peak RSS 41697280 <= 47989555.2 bytes; serialized stats 664 <= 755.55 bytes;
uncompressed lib/app/sig source 95644 <= 98108.85 bytes. Source is 528 bytes
larger than baseline. Serialized rows are not physical storage or compressed
gem size. CPU seconds are the energy proxy; joules, deployed network traffic,
compressed package size, and co-location effects were not measured.

Fallback/history samples use their frozen iteration sources. Their executable
path hashes still match the final tree after the import-only correction.
The final import comparisons and absolute gate use the final source snapshot.

### Remaining audit dimensions and limits

Cache authority is YAML plus adapter gates. Request preload and shared cache
entries rebuild from the adapter. Discarding the memory adapter loses its
overrides and counters; durable ActiveRecord data must survive cache loss.
Existing race, eviction, namespace, and request-cleanup specs pass. Local cache
generations do not establish cross-process invalidation or collapse cold misses.
Those deployment limits were already documented and are not changed here.

History reads scan all memory buckets, then sort matching rows. The fixture
measures this bounded workload; it does not establish a high-cardinality or
multi-process capacity ceiling. The ActiveRecord history query and batch
upserts keep their existing shape. No queue worker or external service is used
by these benchmarks; generated purge jobs remain a host scheduling concern.

Runtime notification capture observes only name/shown/weight on stats.record;
explicit actor mutation additionally emits actor_id on feature_operation.
Only event/field names enter the evidence. Targeted actor IDs remain in gate
data; the host owns subscribers, access, retention, and deletion. Request-local
fields clear after cleanup. Cross-process logs, deployed caches, browser
storage, logout, and deletion were not traced by this local fixture.

Security inspection covers safe YAML loading, parameterized adapter queries,
typed mutations, and the admin policy before actions. Existing request tests
exercise refusal and invalid ranges/settings. Authentication and application
authorization belong to the host; flags are not authorization. No new confirmed
security finding is claimed. HTTP/client and availability checks are scoped to
this local boundary, not live replay. Release workflow inspection is static.
Native interfaces, cloud deployment, network message protocols, and learned
systems are absent from the changed paths. Tenant-specific deployment policy
and effective release credentials were not inspected.

Person-facing surface: ActiveAdmin Flags index and evaluation history. The
repairs leave their layout, copy, controls, and chart aggregation unchanged.
Request specs cover their data path. No new visual surface is introduced; a
rendered hierarchy, keyboard, narrow viewport, loading, and error-state visual
assessment was not performed. No screenshot or full accessibility claim is made.

Coverage gaps were behavioral, not futile source-text checks. Six added specs
execute product logic. Final `bundle exec rspec`: 221 examples, zero failures.
`POLYRUN_COVERAGE=1 bundle exec polyrun parallel-rspec --workers 5 --merge-failures`:
five workers exit zero and merge five fresh coverage fragments. Reporting with
`bundle exec polyrun report-coverage -i coverage/merged.json -o coverage --basename audit --format json,console`
observes 1242/1272 executable lines, 97.64%, across 39 files.

`RUBOCOP_CACHE_ROOT=tmp/rubocop-cache bundle exec rubocop`: 92 files, no offenses.
`bundle exec rbs validate` and `git diff --check`: exit zero.
`ruby usr/bin/check_locale_parity.rb`: en, 2 keys, pass.
`ruby usr/bin/check_loc.rb`: exit zero, existing 212/163-line warnings for
app/admin/features.rb and lib/onni.rb. No style-only splitting was done.

## Next

No repair remains open in the inspected import, fallback-write, and history
contracts. Further pressure work must name a sustained load or deployment
requirement. The diagnostic malformed-import budget miss remains visible.
This episode does not certify the full CI runtime matrix or deployed host UI.

## Source

- [Live work and budgets](../issues/20261113104213_iterative-audit-adapter-contracts.md)
- [Raw evidence and commands](../../benchmarks/engineering_audit_results.json)
- [Benchmark probe](../../benchmarks/audit_probe.rb)
- [Import regressions](../../spec/onni/migrator_importer_spec.rb)
- [Fallback regression](../../spec/onni/stats_buffer_spec.rb)
- [Memory history regressions](../../spec/onni/memory_adapter_spec.rb)
