# Audience filter composition

## Participants

Andrei Makarov.

## Decisions

Implement RFC-0005 following the requested composition improvement. Intersect
configured audience filters, preserve settings on park, and use clear for reset.
Keep variants behind the same visibility expression. Keep statistics at feature
level. Per-group percentages remain design-only.

Contrary pass before the claim ledger: composition alone cannot solve restart
friction because park currently destroys overrides. Empty and absent include
lists need different meanings or removing a cohort can accidentally widen the
audience. Experiment weights currently open visibility without an actor, while
assignment needs an actor. No prior-store runtime or host trace is available to
verify historical OR behavior or the frequency of operator confusion. The
provided notes supply operator testimony, not a measured comparative result.
The plan's claim that statistics usually dominate cost has no measurement here.
The same session selected the design and checks it, so review is not independent.

## Effects

Later scope: RFC-0006 changes off-state statistics and cache representation to
v4; RFC-0007 adds explicit programmatic definitions. Their implementation and
current validation live in [the follow-up issue](20261113174758_evaluation-stats-and-runtime-definitions.md).
The comparison samples and 308-example summary below retain their historical
source digests. The shared matrix proof is refreshed against the later product.

Baseline source: de1ff4e11cb4d62da4760fdb6e9b397d9f682546. This claim ledger
concerns the released typed implementation, not the replacement in RFC-0005.


Claim ledger against the pre-change tree:

- unsupported: the original dependency note attributed exclusivity to avoiding
  OR opacity. RFC-0003 specifies exclusive audiences but does not establish
  that motive. The note now describes the observed contract without that claim.

- supported: Store.audience_matches? selects one type; Registry::Validation
  defaults type to group. Cross-type mutations reject before writes.
- supported: Settings and Store separate power from audience; empty groups are
  closed; boolean visibility has no actor requirement. Store.variant separately
  requires an actor and positive weights.
- supported: Conditions.met? skips conditions for nil actors and ANDs conditions
  after audience selection for present actors. This is targeting, not policy.
- supported: Mutations.park! clears gates before storing powered=false.
  drop_group!/drop_actor! remove include values; they do not exclude an actor.
- supported: Actor.percentage_value hashes feature key and actor identity with
  CRC32. Variant assignment is separate from the percentage ramp.
- partially supported: registered types describe visibility but do not prohibit
  YAML from containing other kinds of defaults; those defaults are ignored by
  the selected audience branch. This distinction explains the composition limitation.
- unverifiable: a commonly used consumer constraint of ~> 1.0 and prior-store
  history. No consumer manifest or prior-store source accompanies these notes.
- unverifiable: relative runtime cost of statistics versus audience matching.
  Keep performance assertions provisional until the recorded probes run.

Before implementation, bundle exec rspec spec/onni/audience_composition_spec.rb
ran 7 examples with 7 failures, exposing missing filters! and ignored AND clauses.
bundle exec rspec spec/onni/power_state_spec.rb ran 6 examples with 1 failure:
park restored the YAML level instead of retaining zero. Both paths subsequently
passed after implementation.

The final adapter review added a custom-adapter regression: reading legacy group
rows froze a string owned by the adapter. The focused composition command then
ran 8 examples with 1 FrozenError failure. Copying legacy group/actor strings
before freezing the snapshot made the same command pass all 8 examples.

Cache lifecycle: YAML and committed adapter rows are authoritative. Request
preloads, application cache entries, and parsed gate snapshots may disappear.
They rebuild from those sources. The memory adapter is itself ephemeral; losing
it loses runtime overrides and power, leaving YAML defaults with pending power.
Filter JSON is parsed when building a snapshot. The memory adapter publishes
immutable snapshots at writes; request preload and application cache reuse them.
The cache representation prefix advances to v3. Existing after-commit local
invalidation and generation fencing still apply. Cross-process invalidation is
unchanged. Persistence specs evict process/request caches and rebuild from
ActiveRecord rows plus YAML.

The expensive audience unit is a registered group membership callback. Typical
composition adds a percentage hash to one include-group scan. The full fixture
also evaluates an actor include, actor exclude, and exclude-group scan. Statistics
remain feature-level and are never keyed by actors or groups.

Visual assessment: ActiveAdmin flag detail, at widths 1440 and 390 in Chrome.
The overview, independent filter cards, variants, and evaluations remain in
separate sections. Set filters show values; absent filters show Not set; empty
include lists state that they match nobody. Inputs have associated labels.
The narrow layout stacks cards and had no horizontal overflow. The form submits
one clause at a time while preserving other settings and power. Browser actions
confirmed Parked after Park, the same 25% and beta_testers after Ready, zero
percentage after a valid edit, removal of only the group clause, and rejection
of 101 without changing the saved zero. Invalid submissions use a plain error
page; Back returns to the editor. Loading placeholders do not apply to these
server-rendered forms. Light theme, keyboard-only operation, and screen-reader
review remain human checks. Screenshots are local review artifacts under tmp,
not release assets. The temporary preview bridge initially failed CSS GET and
POST forwarding; screenshots and interaction claims above use the corrected run.


### Filter combination audit

The initial implementation specs were representative, not an exhaustive
Cartesian matrix. The follow-up adds spec/onni/audience_filter_matrix_spec.rb
and a finite contract model in spec/support/audience_filter_cases.rb.

Expected audiences are explicit fixture sets. The oracle intersects those
sets and requires a positive opener; it does not call Audience, Settings,
Group.member?, or Actor.percentage_value to compute expected answers. The two
synthetic actor identities have fixed CRC32 buckets 49 and 50 for new_checkout.
Group and actor lists exercise a first match, last match, miss, empty list,
and absent clause across those actors. Anonymous evaluation is a third case.

Ordinary flags, experiments with weights, and experiments without weights
share the same filter model. Ordinary fixtures carry inert weights to verify
that assignment still requires the experiment marker. Runtime experiment
weights deliberately replace different registry weights. Each configuration
checks pending, ready, and parked state; effective filter values; current
weights; visibility; and assignment. Ready configurations are parked after
configuration, checked, then resumed. Parked configurations are also resumed.

The first added matrix configured overrides after parking. A focused injected
destructive-park fault initially passed that Ready profile because it never
parked a configured feature. The refined matrix now checks that transition
and the public configuration readers, including configurations whose current
audience is empty. It detects the destructive-park fault.

Partial-update cases cross inheritance, replacement, and removal for every
filter, applying changes sequentially. The order cases permute every filter
write for one adversarial configuration that includes false and a removed
default. They test order independence separately from the value-state matrix;
every write order is not crossed with every value-state combination.

Scope: valid core filter states in the memory adapter, with no application
cache, pure registered group callbacks, and the stated synthetic actors.
Registry defaults are validated definition hashes; YAML parsing remains in
the registry specs. Conditions, expired deadlines, and invalid deadlines
cross filter presence separately. Malformed inputs, ActiveRecord persistence,
cache invalidation, counters, concurrency, and admin forms retain their
focused specs, not a full cross-product with this matrix. Arbitrary actor
identities, callback programs, growing list lengths, and unbounded operation
histories are outside the finite claim. A passing matrix certifies its
registered rows, not every conceivable input or future regression.

usr/scripts/check_audience_filter_matrix.rb runs the unmodified matrix, then
injects named faults into temporary library copies and requires expectation
failures. It checks that each subprocess loaded the copied source. The first
source guard rejected equivalent temporary paths through a symlink alias;
File.identical? now checks file identity. Boot errors do not count as detected
behavioral faults. The saved proof binds product, test, and checker digests.
It contains no host identity or home paths. Production code and its recorded
performance measurements are unchanged by this follow-up. No product UI
surface changed, so no new visual assessment was needed.

Current proof: benchmarks/audience_filter_matrix_results.json, produced by
bundle exec ruby usr/scripts/check_audience_filter_matrix.rb. The unmodified
matrix ran 39 examples with 0 failures. It enumerates
11250 filter-state combinations: everyone has 3 states, each of four
include/exclude lists has 5 states, and percentage has 6 states.

- Composition: 202500 configurations across 3 feature profiles, 2 settings
  sources, and 3 power states, with 3 actor cases and both evaluation APIs.
- Partial updates: 2187 configurations, crossing all 729 inherit/replace/remove
  choices for each feature profile.
- Conditions and expiry: 576 configurations, crossing all 64 filter-presence
  combinations with conditions, expired deadlines, and invalid deadlines.
- Write order: 6480 configurations, checking all 720 orders for the chosen
  complete update, each feature profile, and each power state.
- Lifecycle checkpoints: 67500 parks after configuration and 135000 resumes.
- Unmodified matrix total: 2485458 visible?/variant evaluations. Configuration
  readers and power are checked separately. This count excludes mutant runs.

The checker detected 14 of 14 named injected faults. These cover opener
widening, absent positive openers, empty includes, both exclude kinds,
percentage equality, assignment before visibility, assignment without the
experiment marker, unwanted power changes, destructive park, ignored removal,
lost earlier overrides, conditions, and expiry. This is evidence for those
named faults, not a claim to detect every possible bug. Product and test
digests match the frozen proof. The model also loads on Ruby 3.4.11.

### Final validation

- bundle exec rspec --format progress --format json --out tmp/audience-composition-rspec.json:
  308 examples, 0 failures, 0 pending. Frozen summary and digests:
  benchmarks/audience_validation_results.json.
- POLYRUN_COVERAGE=1 bundle exec polyrun parallel-rspec --workers 5 --merge-failures:
  five workers exited 0; nine fresh coverage fragments, including isolated
  extension probes, merged into coverage/merged.json. Generated fragments were
  cleared first. An earlier combined run exposed test setup ordering: the Rails
  global hook replaced the memory adapter before the custom-adapter example.
  Moving fixture setup into the example's before hook fixed that isolation issue.
- RUBOCOP_CACHE_ROOT=tmp/rubocop-cache make lint: 112 files, no offenses;
  RBS validation exited 0; en locale parity passed with 2 keys. LOC check exited
  0 with warnings on existing files app/admin/features.rb (212), lib/onni.rb
  (166), and usr/lib/release_version_check.rb (177).
- make bench-gate: PASS for 10000 all-feature walks. Frozen numeric result:
  benchmarks/audience_delivery_gate_results.json. This gate's zero RSS field is
  not a memory measurement; native process RSS comes from the comparison probes.
- RBENV_VERSION=3.4.11 ruby -Ilib -ronni -rtmpdir -: stdin smoke check passed
  composed visibility, pending, park, and resume using only the standard library.
- bundle exec ruby usr/scripts/build_admin_assets.rb: stylesheet build succeeded.
- node tmp/audience_browser.mjs: the corrected local browser checks described
  above passed. Temporary screenshots: tmp/audience-desktop.png and
  tmp/audience-mobile.png. Preview and isolated browser processes were stopped.

### Resource comparison

The binding records exact comparison commands and the fixture:
benchmarks/audience_composition_binding.md. Three alternating samples of 100000
operations run per series on the same host, with setup and warmup outside timing.
The new composed flag is compared with equivalent AND checks on separate old
flags, not with an OR store. These are synthetic memory-adapter measurements.

- Everyone without an actor: CPU 0.075536 -> 0.100514 s (+33.1%). Allocations 200011 -> 300011. Peak RSS 32964608 -> 34553856 bytes. Source: benchmarks/audience_global_results.json.
- Two include groups: CPU 0.182289 -> 0.160326 s (-12.0%). Allocations 700011 -> 300011. Peak RSS 34095104 -> 34652160 bytes. Source: benchmarks/audience_group_results.json.
- Global percentage: CPU 0.127395 -> 0.136183 s (+6.9%). Allocations 400011 -> 500011. Peak RSS 33128448 -> 34783232 bytes. Source: benchmarks/audience_percentage_results.json.
- Groups plus percentage: CPU 0.314307 -> 0.190959 s (-39.2%). Allocations 1100011 -> 500011. Peak RSS 33013760 -> 33931264 bytes. Source: benchmarks/audience_composed_typical_results.json.
- Five configured audience clauses: CPU 0.730054 -> 0.239467 s (-67.2%). Allocations 3100011 -> 600011. Peak RSS 32604160 -> 33243136 bytes. Source: benchmarks/audience_composed_results.json.
- Existing seven-path walk: CPU 1.411015 -> 1.544632 s (+9.5%). Allocations 4419145 -> 3919145. Peak RSS 41172992 -> 42516480 bytes. Source: benchmarks/audience_all_results.json.

The aggregate historical ceiling check fails CPU, wall, and source bytes;
allocations, RSS, and stats bytes pass. The before tree already failed source
bytes. The current make bench-gate passes its own rotating-actor workload and
limits. These are different gates. No ceiling was changed. The earlier failed
aggregate run remains in audience_before_global_fast_path_results.json; the
shorter everyone-only path did not establish a material aggregate speedup.
Per-group and percentage absolute ceilings are not published in this tree.

No runtime dependencies, schema, release version, or published package changed.

## Next

- Cut recorded as 2.0.0; deliver with `make release`.
- Hosts migrate code and YAML together from exclusive audience types to filters.
- Keep per-group percentages as a separate design and keep targeted stats out.
- Keep keyboard, screen-reader, light-theme, and large configured-list review
  visible for the admin surface; the browser proof covers the stated widths
  and basic editing, not those unperformed assessments.

## Source

- [RFC-0005](../../rfcs/0005-audience-filter-composition.md)
- [Design](../plans/20261113160847_audience-filter-composition.md)
- [Dependency analysis](../dependencies/20261113155557_onni-exclusive-audience-types.md)
- Released baseline source at commit de1ff4e11cb4d62da4760fdb6e9b397d9f682546:
  lib/onni/store.rb, settings.rb, mutations.rb, conditions.rb, actor.rb
- spec/onni/audience_composition_spec.rb and power_state_spec.rb
- [Comparison binding](../../benchmarks/audience_composition_binding.md)
- [Frozen validation summary](../../benchmarks/audience_validation_results.json)
- [Engineering changelog](../changelogs/20261113162937_audience-filter-composition.md)
- [Matrix specifications](../../spec/onni/audience_filter_matrix_spec.rb)
- [Finite contract cases](../../spec/support/audience_filter_cases.rb)
- [Frozen combination and fault proof](../../benchmarks/audience_filter_matrix_results.json)
