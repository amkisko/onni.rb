# Terminology v1 contract and implementation review

## Participants

Andrei Makarov (@amkisko).

## Decisions

Implement the revised plan directly as the v1 API, with no compatibility aliases.
Use the amended RFC-0003 for the contract and keep the release version separate.
Review the changed power/evaluation, cache, persistence, event, and admin paths;
this is not a repository-wide security or dependency assessment.

## Effects

Follow-up on 2026-11-13 supersedes the ShownChart name with VisibilityChart and
replaces the earlier unstyled screenshots and visual assessment. The pressure
measurements below describe the earlier source snapshot. The follow-up evidence
bundle records the current UI checks, package comparison, and source digests.

### Iterations and contract checks

1. Power/evaluation: 21 initial contract examples produced 20 failures against
   the transitional implementation. Implement ready/pending/parked predicates,
   visible?, ready!/park!, visible_*/drop_*, and level!/level. Park stores a false
   powered marker; clear removes the power decision. Drops and weight changes
   preserve pending, ready, or parked. Ready expiry/zero-level misses stay ready.
2. Persistence/events: use shown_count, skip_count, shown_share, and shown: at
   every runtime writer/reader and sampler. Both reversible schema paths preserve
   totals and indexes: legacy enabled/disabled columns, and transitional
   show_count. The separate generator needs its own explicit template source;
   the first implementation failed that check and was corrected.
3. Admin: the renamed contract initially produced 19 failures in 26 examples.
   Replace power routes with ready/park, add pending scope, update forms and
   notices, keep reserved names on the query-key detail route. Request tests
   confirm one gate SELECT for 50 flags with preload off and on. Forbidden power
   commands return 403 without changing state; unknown commands return 404.
4. Consumers/docs: update RBS, generator defaults, benchmarks, and maintained
   examples; remove Compatibility and old Flag/Store evaluation entry points.
   Amend RFC-0003 and mark the earlier chart contract superseded. Generate the
   AGENTS project description from prayers/project.md via Prayfile. The lockfile
   changes only the local span, manifest checksum, and shifted line positions;
   package versions and source revision remain fixed.
5. Prove: the complete suite has 210 examples and zero failures. RuboCop checks
   90 files without offenses, RBS validates, and English locale parity passes.
   LOC warnings remain for app/admin/features.rb (206) and lib/onni.rb (163).
   Five coverage workers exit zero; the five-fragment merge measures 1225/1258
   repository lines (97.4%). Old local shard fixtures were moved aside and
   rebuilt from spec/dummy/db/schema.rb for the renamed columns.

### Resources, cache, and trace

Calibrate native process RSS and distinct sleep stages before the baseline. Use
five samples per load on arm64-darwin24/Ruby 4.0.2, alternating revision order.
The before snapshot includes its own benchmark scripts so it calls its actual
published API. The same deterministic seven-path L1 fixture performs 100000
walks after 1000 warmups. This is a contract-regression verification after the
earlier fourteen counted optimizations, not a new claim of ten optimizations.

Paired CPU medians are 1.403050 -> 1.392209 seconds, below the 3% directional
floor. Allocations remain 4489001. Do not claim faster evaluation. Maximum
process-lifetime RSS is 42205184 -> 41893888 bytes; no memory reduction claim.
Stats JSON is 657 -> 664 bytes due to the renamed field. Product source is
95580 -> 94675 uncompressed bytes. Three deterministic gem builds per side are
43008 -> 43520 compressed bytes; the packaged baseline source digest matches
the measured before snapshot.

The independent native gate passes all six unchanged earlier limits. Its CPU
median is 1.381321s, wall 1.382137s, allocations 4489001, maximum RSS 42467328
bytes, stats JSON 664 bytes, and source 94675 bytes. Separate pending/parked
probes with stats enabled each allocate 200009 objects for 100000 evaluations
and record no buckets. They return before audience, conditions, or stats work;
the executable contract specs also observe those skipped calls.

The rotating-actor evaluation and eight-writer SQLite gates pass existing limits.
The SQLite retained wall-median row reports 1600 counts, zero lock waits, and
zero write errors. The stock runner retains one row after five samples; it does
not provide five raw rows for variance analysis. Native probes retain all rows.
CPU seconds are the energy proxy. No network, joules, co-location, or sustained
load improvement is claimed.

Cache generations and adapter namespaces remain process-local. Request preload
is still a request snapshot. The existing stale-fill and adapter-replacement
specs pass with parked markers. Rebuild after cache/request loss from adapter
gates plus YAML; lost memory-adapter overrides remain unrecoverable without an
external durable source. No cross-process invalidation guarantee is added.

The trace fixture records field names and operation names only. Stats fields
are name/shown/weight; mutations expose actor_id/group_name/level when relevant.
All nine revised operation names are observed. No actor values, cache namespace
values, hostnames, or absolute paths are in the tracked evidence. Retention and
notification subscriber access remain host-owned.

### Person-facing surface

Inspect the Rails-rendered Flags index and detail pages at 1280 and 390 pixels
with ActiveAdmin's stylesheet loaded. The earlier dummy head omitted CSS and
JavaScript entirely. Remove that override; compile the installed ActiveAdmin
Tailwind plugin with ActiveAdmin and Onni sources, then serve CSS and JavaScript
locally. The asset request spec fetches the stylesheet and every importmap entry.

Replace all four original captures and add narrow index and populated-history
captures. Section headings, form labels, status labels, and chart legends are
legible. Browser checks pass Ready/Park at both widths, level save, Add group and
Remove group, history range selection, expanded counts, and empty history.
The narrow index table scrolls inside its container; its commands remain usable.
Both narrow pages measure 390 pixels without document overflow. Menu opening and
theme toggling work, and no JavaScript page errors were observed. Navigation now
uses Flags for the menu, breadcrumbs, and return links. Keep each chart legend
line beside its label under Tailwind's SVG base styles.

The bridge base64-encodes static file bodies and follows Rack redirects before
returning HTML to the browser. Native redirect status and error responses remain
covered by request specs. No loading interface is introduced. A human should
check host-specific theme and policy customizations; this run assesses the
styled dummy host, not every host application.

### Follow-up validation and dependency impact

The renamed chart spec initially failed to load VisibilityChart. The asset spec
then failed on the missing stylesheet. After implementation, the focused admin
run passes 26 examples, the complete suite passes 211 examples, and five parallel
coverage workers exit zero. The merged coverage is 1229/1262 executable lines.
Lint checks 91 files without offenses, RBS validates, and English locale parity
passes. LOC warnings remain for app/admin/features.rb (212) and lib/onni.rb (163).
The build script also passes its explicitly targeted RuboCop check. Exact
commands and observed results are in the follow-up evidence bundle.

Add Tailwind CSS and its CLI at 4.3.5 in a private, test-only npm manifest. The
installed ActiveAdmin plugin already supplies the theme; do not duplicate it or
add a Ruby asset pipeline. The official CLI instructions specify these two build
packages. This is a new dev/test tool graph, not a runtime upgrade. The required
adaptations are locked installation, source scanning, static serving, and a build
before CI request specs. Those paths run locally. No optional watch, Vite, or
WASM integration is adopted. The npm audit reports zero known vulnerabilities;
this is a scoped advisory check, not a complete supply-chain assessment. Add the
same advisory check to CI and grouped npm updates. Ruby dependency graphs stay
unchanged. Linux CI has not been executed in this local session.

Compare isolated source copies with three alternating boot-plus-admin-GET samples
per side on arm64 macOS and Ruby 4.0.2. CPU medians are 1.000191 -> 0.996564 seconds;
median peak RSS is 158203904 -> 162627584 bytes. Make no speed or memory reduction
claim. The new local npm tree occupies 25382912 allocated bytes (23726028 logical
file bytes), versus no npm tree before. Deterministic compressed gem builds are
43520 -> 44032 bytes; the test assets and npm packages are excluded. The source
snapshots and raw samples are identified in the evidence bundle. These figures
do not refresh or replace the earlier evaluation pressure measurements.

Keep shown_count, skip_count, and shown_share as outcome names. Keep the migration
name ShownStatsGenerator because it specifically renames show_count to
shown_count. The public stats_scale_sampled_hits setting and scale_sampled_hits
overview field remain candidates for a coordinated counts terminology change.
The stats_enabled setting still names the statistics master switch, so it does
not conflict with flag power states. Keep published table names, gate keys, and
Features controller/routes intact.

### Default-group follow-up

The operator changed the YAML default from boolean to group. Amend RFC-0003
before implementation. A metadata-only new_checkout declaration normalizes to
an empty group, starts pending, and remains invisible after ready! until a group
matches. Specs load the actual YAML, exercise add/drop group visibility, reject
nonmatching actors, apply YAML group defaults, and retain expiry enforcement.
A separate Flag.type check covers a raw definition without a normalized type.
Explicit boolean behavior remains covered by the existing store specs.

The first focused command produced 26 examples with 5 failures:

    bundle exec rspec spec/onni/default_group_spec.rb spec/onni/registry_spec.rb spec/onni/flag_spec.rb

After the two default changes, the broader run passes 66 examples:

    bundle exec rspec spec/onni/default_group_spec.rb spec/onni/registry_spec.rb spec/onni/flag_spec.rb spec/onni/store_spec.rb spec/onni/request_preload_spec.rb spec/requests/admin_features_spec.rb

The final commands pass 215 examples and the quality checks respectively:

    bundle exec rspec
    RUBOCOP_CACHE_ROOT=<temporary writable cache> make lint

The lint command checks 92 files with no offenses, validates RBS, and confirms
English locale parity. The existing 212-line admin file and 163-line entry point
still produce LOC warnings. The cache path is omitted from this public record.

Person-facing surfaces are README and the generated YAML example. The minimal
sample appears first; the next example explicitly selects experiment, and the
upgrade section explains how to retain global boolean visibility. The existing
group form is exercised through a metadata-only dummy flag in request specs.
No screen layout or control changes, and no additional visual assessment is
claimed. Earlier pressure and UI resource figures remain frozen evidence for
their source snapshots, not measurements of this default-group revision.

### Claims and dependent checks

Contrary cases: soft zero must remain ready; expired ready must remain ready;
drops and variants must preserve pending/parked; unknown names must not become
pending; old APIs must fail; old admin policy/action names must be absent;
both migrations must restore their original schemas on rollback. Specs cover
each named case. The first complete run found one stale level-event expectation;
update its consumer from percentage to level instead of restoring the old field.

Supported: maintained API and schema claims link to executable specs and RFC-0003.
Supported with scope: numerical claims freeze from the evidence bundle; timing
differences below the measured floor are not directional improvements.
Outdated and corrected: README formerly said YAML variants override imported
runtime variants. The runtime override wins, as the existing variant specs prove.
Supported external SQL syntax: PostgreSQL INSERT documentation confirms bare SET
targets and existing-row/excluded references. SQLite executes the upsert specs;
PostgreSQL execution remains unverified and is explicitly described that way.

Historical reviews, changelogs, and raw pressure samples retain their original
fields and numbers. Current live work and bindings link to this revision.

## Next

No implementation correction remains in the selected scope. Before release,
coordinate the matching host schema migration, call sites, policies, custom
adapters/samplers/chart partials, and confirm host theme customizations at narrow
width.
Cross-process cache consistency, deduplication, and gate-row key renaming stay
deferred as the plan specifies.

## Source

- [Live implementation](../issues/20261113091112_ready-park-visible-terminology.md)
- [Amended RFC-0003](../../rfcs/0003-show-skip-typed-flags.md)
- [Commands, raw samples, and trace inventory](../../benchmarks/terminology_v1_results.json)
- [Follow-up commands, samples, and claims](assets/20261113091112_visibility-ui-evidence.json)
- [Narrow index](assets/20261113091112_ready-park-visible-index-390.png)
- [Narrow populated history](assets/20261113091112_ready-park-visible-history-390.png)
- [Tailwind CLI setup](https://tailwindcss.com/docs/installation/tailwind-cli)
- [Index screenshot](assets/20261113091112_ready-park-visible-index.png)
- [History screenshot](assets/20261113091112_ready-park-visible-history.png)
- [Narrow level form](assets/20261113091112_ready-park-visible-level-390.png)
- [Narrow empty history](assets/20261113091112_ready-park-visible-empty-390.png)
- [PostgreSQL INSERT syntax](https://www.postgresql.org/docs/current/sql-insert.html#SQL-ON-CONFLICT)
