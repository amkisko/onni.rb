# Evaluation statistics and programmatic definitions

## Participants

Andrei Makarov.

## Decisions

Implement RFC-0006 and RFC-0007. Record completed known evaluations by default,
including pending and parked misses. Keep global master/ignore vetoes, add
feature YAML and runtime collection/rate settings, and retain call-site opt-out.
Preserve adapters when ordinary application configuration changes.

Provide explicit process-local define! with mandatory description and parseable
expiration. Prefer features.yml as the team catalogue. Do not add automatic
declarations, a database definition registry, or new admin explanatory panels.

## Effects

Initial inspection before this change: Store.visible? returns before Stats.record when unpowered;
Store.variant also returns early for nil actors and non-experiment names.
record_stats: false already exists. Application stats_enabled defaults true and
stats_sample_rate defaults 1.0; the install template instead uses 0.1. Feature
stats defaults and mutations do not exist. Registry requires YAML definitions.
Onni.configure currently resets the adapter even for an unrelated stats change.

The pending/parked omission matches the former RFC-0003 contract. The report
identifies an observability gap; the available source does not establish a
new regression between released versions. record_stats: false already offered
call-site opt-out, but feature-level inheritance and runtime controls were absent.

Completed evaluations now record their actual boolean or assignment outcome.
Unknown names still allocate no counters. Explicit true overrides a feature
opt-out, while application master/ignore controls and sampling still apply.
Runtime stats! overrides persist through the adapter, leave power unchanged,
survive park, and reset on clear. The importer validates stats overrides before
copying them. Invalid persisted policy suppresses collection, not visibility.

Ordinary configure changes retain the adapter. Changing adapter selection or
concurrency remains an explicit rebuild. Disabling buffering retains accepted
counts until reset/flush. Cache generations advance even while caching is off,
and the representation prefix is v4. YAML and committed gates/counters rebuild
snapshots, preloads, and application caches; memory-adapter state is ephemeral.

define! validates metadata and the same supported definition settings as YAML,
copies caller-owned values before publication, and rejects cyclic/deep or
unsupported shapes. Replacing a programmatic definition updates expiration
without erasing gates or counts. Registry reload retains these definitions
and rejects YAML collisions. They survive adapter reset, not process exit;
the host must initialize them in each worker. Existing YAML metadata remains
compatible; descriptions and expiration are recommended there and mandatory
at the new entry point.

Before implementation, the initial evaluation-policy/programmatic-definition
spec run had 10 examples and 10 failures. It exposed missing off-state counters,
missing feature policy/define! methods, and adapter loss during configure.
The cache reattachment and buffer-disable regressions then failed 2 of 12
focused examples before fixes; the expanded focused run passed 15 examples.
The importer statistics case failed with gates=0/skipped_gates=2 before support
and then passed with gates=1/skipped_gates=1. Cyclic input initially produced
SystemStackError; bounded copying now rejects it with ArgumentError.

The generated initializer is exercised against its generated migration and
SQLite: a pending evaluation stays buffered until reset, then persists one
skip with sample rate 1.0. The old content assertion for rate 0.1 is replaced
by this executable behavior check.

No new UI controls or explanatory panels were added. The person-facing changes
are README examples and contract documentation, reviewed for defaults,
precedence, required metadata, collision failure, and process lifetime. A visual
assessment of new interactive/loading/empty states does not apply; the earlier
audience editor assessment remains scoped to that editor. No dependency or
schema change, release, or publication occurred.

### Validation

- bundle exec rspec --format progress --format json --out tmp/evaluation-runtime-rspec.json:
  331 examples, 0 failures, 0 pending. Final summary and source/spec digests:
  benchmarks/evaluation_runtime_validation_results.json.
- POLYRUN_COVERAGE=1 bundle exec polyrun parallel-rspec --workers 5 --merge-failures:
  all 5 workers exited 0; 15 freshly generated fragments merged. Line coverage
  is 1532/1567 (97.77%) across 49 files. Feature policy covers all 42 executable
  lines; programmatic definitions cover 45/47. This is line coverage, not a
  proof of every possible input. Generated fragments were cleared before run.
- bundle exec ruby usr/scripts/check_audience_filter_matrix.rb:
  39 examples, 0 failures; 11250 finite filter combinations, 2485458 public API
  evaluations, and 14/14 injected faults detected against the current product.
  This preserves the audience matrix's stated finite scope; statistics controls
  have their own 324-case power/inline/YAML/runtime/master/rate cross-product.
- RUBOCOP_CACHE_ROOT=tmp/rubocop-cache make lint:
  117 files, no offenses; RBS validation and en locale parity (2 keys) pass.
  LOC check exits 0 with warnings: app/admin/features.rb 212, lib/onni.rb 171,
  usr/lib/release_version_check.rb 177.
- make bench-gate: exit 0. Exact numeric result and current product digest:
  benchmarks/evaluation_stats_delivery_gate_results.json. Native RSS and the
  three before/after series are in the linked resource comparison.
- git diff --check: exit 0.

The standalone stdlib-only check exited 0 and printed Ruby 3.4.11 stdlib smoke:
PASS. Exact command:

```sh
RBENV_VERSION=3.4.11 ruby -Ilib -ronni -e 'Onni.configuration.features_path = nil; Onni.define!(:new_checkout, description: "Core runtime check", expires_at: "2099-01-01", everyone: true); abort unless !Onni.visible?(:new_checkout); Onni.ready!(:new_checkout); abort unless Onni.visible?(:new_checkout); Onni.stats!(:new_checkout, enabled: false); Onni.visible?(:new_checkout); Onni.park!(:new_checkout); abort if Onni.visible?(:new_checkout, record_stats: true); rows = Onni::Stats.for(:new_checkout); abort unless rows.sum { |row| row["shown_count"] } == 1 && rows.sum { |row| row["skip_count"] } == 2; puts "Ruby #{RUBY_VERSION} stdlib smoke: PASS"'
```

## Next

- Cut recorded as 2.0.0 together with RFC-0005; deliver with `make release`.
- Initialize programmatic definitions consistently in every consuming worker,
  or retain the recommended YAML catalogue.

## Source

- [RFC-0006](../../rfcs/0006-evaluation-statistics-policy.md)
- [RFC-0007](../../rfcs/0007-programmatic-feature-definitions.md)
- lib/onni/store.rb, stats.rb, stats/sampler.rb, registry.rb, configuration.rb
- [Audience composition evidence](20261113162937_audience-filter-composition.md)
- [Resource comparison and exact commands](../../benchmarks/evaluation_stats_binding.md)
- [Engineering changelog](../changelogs/20261113183543_evaluation-stats-and-runtime-definitions.md)
- [Frozen validation summary](../../benchmarks/evaluation_runtime_validation_results.json)
