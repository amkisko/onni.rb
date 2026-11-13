# Show/skip terminology as v1.0 vision

Design-only. Not committed work. Target: Onni 1.0 public contract. Pre-1.0 (0.x) may ship aliases and migrations in steps; 1.0 drops enable/disable vocabulary from the published API.

## Participants

Andrei Makarov (@amkisko)

## Decisions

### Goal

Make feature flags and their configuration visible in code (YAML registry: type, defaults, expiry, conditions, variant shape) while runtime power and overrides stay mutable in the adapter/DB. Replace enable/disable language with show/skip so API, admin copy, stats columns, and instrumentation use one verb family. Treat this rename plus typed flags as the v1.0 vision, not a drive-by 0.x cosmetic patch.

### Vocabulary (locked)

Public evaluation and mutation:

- `show?(name, actor = nil, record_stats: true)` - does this actor get the feature now?
- `show!(name)` - put the feature in play (powered) using YAML type and defaults
- `skip!(name)` - hard-off: show to nobody; cheapest fail-closed path; no stats writes
- `show_group!(name, group)` / `skip_group!(name, group)` - partial show/skip for a group slice
- `show_percentage!(name, n)` / `skip_percentage!(name)` - partial show at level 0..100; skip_percentage! removes the percentage rule (not "skip N percent")
- `clear!(name)` - wipe runtime settings (groups/actors/percentage/variants overrides) back toward empty/zero; YAML defaults remain the contract (powered behavior under clear! still open under Next)
- `variants!(name, hash)` / `variants(name)` - experiment weights (not forced into show_* naming)

Rejected as primary API verbs: enable/disable, on/off, activate/deactivate, turn_on/turn_off, entered, close! (synonym noise for skip!). Appliance on/off informed hard-off resource goals but product language is show/skip.

Stats outcomes (while powered only):

- `show_count` - evaluations (later: request-deduped counts) that passed the gate and count as seeing the feature
- `skip_count` - powered evaluations that did not pass (audience/level/group miss)
- `show_share` - show_count / (show_count + skip_count)

Do not add `show!`/`skip!` as stats APIs. Counts are side effects of `show?` (or a later explicit record helper), not separate power switches.

Config that stays (different domain):

- `stats_enabled` - master switch for the stats subsystem
- `record_stats:` kwarg on `show?` / `variant` - inspect without recording

### YAML contract (locked direction)

Every flag in `config/features.yml` declares identity in git:

- `type` - boolean | percentage | group | actors | experiment (exact enum still under Next)
- type defaults - e.g. `level` / percentage default, default `groups`, default `variants`
- existing fields stay - `description`, `expires_at`, `conditions`

Unknown names fail closed. Runtime adapter holds powered state and overrides. Effective settings = DB override if present else YAML default else fail closed for that setting.

`show!` is allowed for every type. Type-specific settings still apply: e.g. percentage flag after `show!` with YAML `level: 0` shows to nobody until `show_percentage!(..., n)`. Multi-gate OR (boolean plus percentage plus group on one flag) is not the v1.0 model; one type per flag.

### Hard-off resource contract (locked)

`skip!` means:

1. No audience receives the feature.
2. Runtime settings cleared or powered bit false so evaluation fails closed early.
3. Lowest CPU/memory path on `show?` (no group membership, no percentage hash, no conditions work when not powered / no gates).
4. No `show_count` / `skip_count` writes.

Soft miss (powered, `show?` false) may still increment `skip_count` for rollout analysis. Soft dial `show_percentage!(..., 0)` is not hard-off.

### Database (locked direction)

Keep table names:

- `onni_features`
- `onni_feature_gates`
- `onni_feature_stat_buckets`

Rename stat columns only:

- `enabled_hits` -> `show_count`
- `disabled_hits` -> `skip_count`

Do not rename tables to verb-shaped names. Gate storage keys (`boolean`, `actors`, `groups`, `percentage_of_actors`, `variants`) may stay through a migration window or be normalized later (see Next). Models: keep `Feature`, `Gate`, `StatBucket`; rename `HitChart` away from "hit" (e.g. `ShowChart` or `FlagChart`) when implementing.

### Admin and host surface (locked direction)

- Buttons and notices: Show / Skip
- Scopes: all / showing / skipped (exact slug under Next)
- Status copy: Showing / Skipped (hard-off), not Enabled / Disabled
- Group actions: show/skip group; percentage field labeled for show_percentage
- Chart legend and data attributes: show_count / skip_count
- Page actions and reserved route keys: show / skip (replace enable / disable)
- Host authorization methods documented as `show?` / `skip?` for page actions (breaking for Pundit/CanCanCan hosts)

### Instrumentation (locked direction)

`feature_operation.onni` operation names: `:show`, `:skip`, `:show_group`, `:skip_group`, `:show_percentage` (or `:show_level` if that name wins), `:variants`, `:clear`.

`stats.record.onni` payload uses show/skip outcome (`:show` boolean or `:outcome`), not `:enabled`.

### Compatibility

0.x may expose aliases from enable/disable to show/skip with deprecation. v1.0 removes enable/disable from the published Ruby API, admin routes, operation names, and stat column names. README and AGENTS project blurb use show/skip. Historical docs under reviews/issues/dependencies are not rewritten.

Auth reminder stays: `Onni.show?` answers rollout/experiment visibility, not authorization. Keep privileged actions behind a real policy layer.

## Effects

None yet. Design-only plan; no code, schema, or release shipped under this note.

## Next

Open product decisions before implementation issue:

1. `show_percentage!` vs `show_level!` (and read method `percentage` vs `level`) - percentage matches show_percentage!; level matched earlier dial language.
2. `skip?` as hard-off inspect helper, or only `show?` plus admin powered bit.
3. Does `clear!` leave powered true (empty settings, fail closed) or also perform `skip!`?
4. Actor targeting: `show!(name, actor)` / `skip!(name, actor)` vs explicit `show_actor!` / `skip_actor!`.
5. Exact YAML `type` enum and whether `type` is required or defaults to `boolean`.
6. Admin scope slugs: `showing`/`skipped` vs `show`/`skip`.
7. Whether gate key `percentage_of_actors` renames in DB at v1.0 or only API renames.
8. Request (or actor) dedupe for `show_count` so counts mean "saw the feature" not raw `show?` call volume - same release as rename or follow-up.
9. Alias window length on 0.x before v1.0 cut.

Implementation sequencing (when an issue opens):

1. Specs that lock show/skip contracts and hard-off no-stats path.
2. Ruby API + Flag + Store evaluation (type-aware) with aliases.
3. Stat column migration + HitChart/admin/sampler/buffer payload rename.
4. ActiveAdmin routes, copy, scopes, reserved keys.
5. YAML type validation + generator templates + README.
6. Migrator/importer mapping from legacy gates.
7. Instrumentation operation names.
8. CHANGELOG / docs/changelogs entry; pressure ceilings recalibration if hot-path names change.
9. v1.0: remove aliases and enable/disable from public surface.

Do not start coding from this plan until an issue is opened and open decisions above are resolved or explicitly deferred.

## Source

- Session design thread on enable/disable replacement, appliance power states, YAML visibility, coverage/flag analytics naming, and show/skip family (this plan).
- Current public API and stats shape: `lib/onni.rb`, `lib/onni/store.rb`, `README.md` Runtime API and Stats sections.
- Schema and generator: `lib/generators/onni/templates/create_onni_features.rb.tt`, `spec/dummy/db/schema.rb`.
- Admin: `app/admin/features.rb`, `lib/onni/admin/flags_query.rb`, `app/models/onni/hit_chart.rb`.
- Peer vocabulary researched for contrast (not adopted as primary): Flipper enable/disable; LaunchDarkly on/off and evaluation counts; Unleash impressions; SimpleCov/Codecov hit-miss coverage; IEC/IEEE power on/off/sleep for hard-off resource metaphor only.
- Docs conventions: `docs/plans/` design-only until an issue opens; five-section note shape.
- Repository: https://github.com/amkisko/onni.rb
