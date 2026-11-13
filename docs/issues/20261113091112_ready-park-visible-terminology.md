# Ready, park, and visible terminology

## Participants

Andrei Makarov (@amkisko).

## Decisions

Implement the revised terminology plan as the direct v1 API. The operator chose
to remove enable/disable and transitional show/skip API names now. Do not add
start/pause aliases or combined ready! keyword variants. Keep the existing gem
version until a release is prepared.

Resolve the open behavior: clear! removes runtime settings and restores pending;
pending means no power decision since initialization or the latest clear. Park
is explicit hard-off, ready is power on. A zero level remains ready. Only
level!/level expose the percentage dial; level!(name, 0) is the soft-zero command.
Use VisibilityChart, shown_count, shown_share, and shown: payloads. Keep skip_count for
soft misses, existing table/gate storage names, and per-evaluation counting.

Work in iterations: power/evaluation API and state transitions; stats persistence
and migration; admin routes/scopes/forms; signatures and maintained documentation;
then full checks, visual assessment, and pressure verification. Extend RFC-0003
in place. Preserve historical reports and measurement evidence, marking their
vocabulary and budgets as historical when necessary.

The operator subsequently chose group as the default YAML type. A declaration
may contain only expires_at and description. Preserve an empty group audience;
ready! alone does not grant visibility. Explicit boolean remains the global
visibility type. This supersedes the earlier implicit boolean default in RFC-0003.

## Effects

Complete all five iterations. Power, visibility, audience slices, the level
dial, shown/skip statistics, and VisibilityChart now use the selected v1 contract.
Remove old APIs rather than delegating them. Pending and parked remain distinct
through persistence, cache invalidation, preload, and admin scopes.

Both reversible migration paths preserve counts and indexes. Admin actions use
ready/park; malformed forms, unknown keys, reserved route keys, and denied power
commands have executable checks. Update maintained docs and amend RFC-0003;
preserve historical results. Generate the project blurb through Prayfile using
prayers/project.md without editing managed instruction blocks manually.

The full suite, lint/type/locale checks, five-worker coverage, native pressure
limits, rotating-actor gate, and SQLite write gate pass. Source digests match the
measured code. No ceiling is widened and no CPU improvement below the noise
floor is claimed. Existing pressure optimizations and other uncommitted work are
preserved. Exact commands and raw samples live in the linked evidence bundle.

Follow-up review supersedes the chart-name decision with VisibilityChart,
because the chart contains both shown and skipped evaluations. Keep outcome
counters and sampler payload names. Use Flags throughout menu, breadcrumbs, and
return links; use Add group and Remove group commands. Retain legacy hit-shaped
configuration and persistence identifiers for a separately coordinated contract
change.

Restore ActiveAdmin's default head in the dummy app. Build its own Tailwind
plugin with ActiveAdmin and Onni sources and serve CSS and JavaScript locally.
The new asset request test first failed on the absent stylesheet; it now checks
all referenced assets. CI and make test build the same test-only assets.

Replace the four unstyled review images and add narrow index and history images.
Browser interactions pass for power, level, groups, history, and empty data with
the stylesheet loaded. Neither 390-pixel page overflows; the index table scrolls
inside its container. The Rack redirect-bridge limitation remains. Commands,
raw resource samples, and updated visual evidence are in the linked review.

The default-group follow-up changes registry normalization and the shared type
fallback to group. The install template starts with the requested metadata-only
new_checkout example. README leads with that example, then shows explicit
experiment configuration and calls out the implicit-boolean upgrade change.
The dummy audience flag omits type and groups, exercising the same path through
the existing ActiveRecord admin flows. Boolean-focused specs now declare that
type explicitly.

Validation: bundle exec rspec spec/onni/default_group_spec.rb
spec/onni/registry_spec.rb spec/onni/flag_spec.rb first produced 26 examples with
5 failures. After implementation, the focused six-file run passes 66 examples;
bundle exec rspec passes 215 examples with zero failures. RUBOCOP_CACHE_ROOT set
to a temporary writable cache with make lint passes 92 files, RBS validation, and
locale parity; existing LOC warnings remain. The review records exact commands.

## Next

No implementation task remains in this scope. Review and coordinate host schema,
call-site, policy, adapter/sampler, and chart-partial upgrades before release.
Confirm host-specific theme and policy customizations at narrow width. Keep deduplication, gate-key renaming,
and cross-process cache consistency deferred.

## Source

- [Revised plan](../plans/20261113054615_show-skip-terminology-v1.md)
- [RFC-0003](../../rfcs/0003-show-skip-typed-flags.md)
- [Previous implementation](20261113060000_show-skip-typed-flags.md)
- [Previous pressure episode](20261113071037_pressure-show-skip-evaluation.md)
- [Verification review and screenshots](../reviews/20261113091112_ready-park-visible-terminology.md)
- [Raw evidence and exact commands](../../benchmarks/terminology_v1_results.json)
- [Engineering changelog](../changelogs/20261113091112_ready-park-visible-terminology.md)
