# Show/skip APIs and typed flags

Intent: make runtime visibility, audience configuration, and evaluation counts use
one vocabulary while preserving a deprecated Ruby transition path during 0.x.

## Participants

Andrei Makarov (@amkisko), named in the source plan.

## Decisions

Implement RFC-0003. Use show_percentage!, explicit actor mutations, a boolean
omitted type, showing/skipped scopes, and clear! as hard-off. Keep deprecated Ruby
entry points through 0.x and remove them at 1.0. Defer request/actor deduplication
and legacy gate-key renaming.

## Effects

Add typed defaults and validation for boolean, percentage, group, actors, and
experiment flags. Runtime overrides take precedence, including empty audiences.
Power stays independent of targeting. skip! and clear! remove runtime gates;
show? exits before audience checks, expiry parsing, conditions, and stats writes
when power is absent. A powered zero-percent rollout records a skip.

Rename counters to show_count/skip_count and HitChart to ShowChart. Update the
sampler, buffer, adapter, notifications, chart series, templates, and signatures.
Generate a reversible existing-host column rename with onni:stats_rename. Existing
historical totals remain as recorded, including legacy hard-off misses. New
installs already have the new columns.

Map compatible legacy gate imports to the declared type, map boolean rows to
power, and skip malformed values. Actor-only legacy gates cannot turn a boolean
flag into a global audience. Atomic audience mutations use a memory lock or an
ActiveRecord feature-row transaction. Relative experiment weights cannot select
a zero-weight variant.

The ActiveAdmin Flags index and detail surface use Show/Skip, runtime power,
type-specific settings, and show/skip counts. Reserved show/skip flag names use
the query-key detail route. Request specs cover commands, a powered zero-percent
status, invalid input, authorization, custom variant names, empty charts, and
accessible chart labels. Local browser previews cover the rendered detail content
at 1280px and 390px. The dummy host omits ActiveAdmin styles, so full host layout,
narrow-screen fit, and styled interactive states need host-side visual review.
There is no asynchronous loading state on these server-rendered forms.

Validation:

- bundle exec rspec spec/onni/show_skip_spec.rb initially failed all eight examples because the new APIs did not exist. Subsequent regression examples exposed default-array mutation and legacy power edge cases before their fixes.
- bundle exec rspec spec/onni/migrator_importer_spec.rb exposed malformed imported variants before validation was added.
- bundle exec rspec spec/onni/migrator_importer_spec.rb spec/onni/compatibility_spec.rb spec/requests/admin_features_spec.rb passed 23 examples.
- bundle exec rspec passed 184 examples, zero failures, seed 44011.
- bundle exec rspec spec/requests/show_charts_admin_spec.rb passed eight examples after the final accessible chart title edit.
- POLYRUN_COVERAGE=1 bundle exec polyrun parallel-rspec --workers 5 --merge-failures completed five workers with exit 0 and generated coverage/merged.json.
- bundle exec polyrun report-coverage -i coverage/merged.json -o coverage --basename coverage --format json,cobertura generated both report formats.
- RUBOCOP_CACHE_ROOT=tmp/rubocop-cache make lint passed: 86 files without offenses, RBS validation, locale parity, and the LOC check. The LOC check reports nonfatal warnings for app/admin/features.rb (202), lib/onni/adapters/memory.rb (169), and lib/onni.rb (154).
- git diff --check passed.

Resource units remain one seven-path evaluation walk and one direct hourly stats
write. The initial gates failed existing heap ceilings before implementation.
Recalibrate with SCENARIO=matrix SAMPLES=5 bundle exec ruby benchmarks/load.rb and
SCENARIO=matrix SAMPLES=5 WRITERS_L1=8 OPS=200 bundle exec ruby benchmarks/stats_write.rb.
Use the larger final calibration/check heap observation with 1.25 headroom for the
evaluation ceiling; wall-median selection alone did not bound GC-dependent heap
variation. RSS returned zero and is not usable evidence of process memory.

Observed gate samples below freeze producing-artifact values; seconds are rounded
to six decimal places and heap deltas are copied as bytes. These samples do not
establish a performance improvement or isolate the cause of host timing variation.

Initial gate_all_features_10000: wall 0.168601s, CPU 0.170416s, heap delta 3746305 bytes.

Final gate_all_features_10000: wall 0.168031s, CPU 0.169469s, heap delta 150574 bytes.

Initial gate_direct_w8_ops200: wall 0.267650s, CPU 0.273126s, heap delta 11394235 bytes.

Final gate_direct_w8_ops200: wall 0.285333s, CPU 0.287668s, heap delta 14201124 bytes.

Final SCENARIO=gate bundle exec ruby benchmarks/load.rb passed. Final
SCENARIO=gate WRITERS_L1=8 OPS=200 bundle exec ruby benchmarks/stats_write.rb passed
with 1600 recorded counts, zero lock waits, and zero write errors.

SQL claim check: before checking documentation, challenge the inference that
SQLite execution proves PostgreSQL execution and inspect renamed targets and RHS
references independently. The same author performed this check. PostgreSQL INSERT
documentation supports bare SET targets and table/excluded RHS access. The source
SQL follows that form. Outcome for the README syntax claim: supported; add the
primary documentation link. Outcome for PostgreSQL runtime execution: unverifiable
in this session; qualify the README instead of claiming an engine run. No new
package or runtime pin changed.

## Next

Use the implementation issue for remaining operator actions and deferred work.

## Source

- [RFC-0003](../../rfcs/0003-show-skip-typed-flags.md)
- [Implementation issue](../issues/20261113060000_show-skip-typed-flags.md)
- [Upgrade instructions](../../README.md#upgrading-to-showskip)
- [Contract specs](../../spec/onni/show_skip_spec.rb)
- [Migration spec](../../spec/generators/stats_rename_generator_spec.rb)
- [PostgreSQL INSERT syntax and ON CONFLICT](https://www.postgresql.org/docs/current/sql-insert.html#SQL-ON-CONFLICT)
