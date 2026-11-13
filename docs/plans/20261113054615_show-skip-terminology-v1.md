# Ready / park / visible terminology as v1.0 vision

Design source, superseded in place for vocabulary layers. First implementation
under RFC-0003 shipped a single show/skip family (`show!`, `show?`, `show_count`,
admin action `show`). This note splits power (ready/pending/parked) from
evaluation (`visible?`) and stats (`shown_count` / `skip_count`). Follow-up
implementation and RFC amendment are listed under Next. Target: Onni 1.0 public
contract. Pre-1.0 (0.x) may ship aliases and migrations in steps; 1.0 drops
enable/disable and transitional show/skip power verbs from the published API.

## Participants

Andrei Makarov (@amkisko)

## Decisions

### Goal

Make feature flags and their configuration visible in code (YAML registry: type,
defaults, expiry, conditions, variant shape) while runtime power and overrides
stay mutable in the adapter/DB. Use separate verb layers for power, actor
visibility evaluation, audience slices, dial, and stats so one word is not
overloaded for Rails/ActiveAdmin `show`, authorization policy `show?`, soft
evaluation miss, and total hard-off. Treat typed flags plus this vocabulary as
the v1.0 vision.

### Layers (locked)

Power (runtime virta; admin status; no actor):

- `ready!(name)` - power on using YAML type and defaults (gloss: started)
- `park!(name)` - hard-off total: nobody gets the feature; cheapest fail-closed path; no stats writes (gloss: paused)
- `ready?(name)` - powered / started?
- `pending?(name)` - no power decision since initialization or clear!
- `parked?(name)` - hard-off / paused?

Glosses only (not a second public primary pair): started ~= ready, paused ~= parked.
`start!` / `pause!` are not equal published API beside ready/park; optional 0.x
aliases at most, removed for 1.0. Do not ship both pairs as permanent synonyms.

Evaluation (call-site; actor-aware):

- `visible?(name, actor = nil, record_stats: true)` - does this actor get the feature now?
- Replaces `show?` so call-sites and docs do not collide with Pundit/CanCanCan
  `show?` or ActiveAdmin REST show.

Audience slices (add/remove one slice; a visible-slice also powers; a drop-slice
keeps power and masks defaults):

- `visible_group!(name, group)` / `drop_group!(name, group)`
- `visible_actor!(name, actor)` / `drop_actor!(name, actor)`
- Transitional aliases from shipped `show_group!` / `skip_group!` / `show_actor!` /
  `skip_actor!`

Dial (percentage type; not a ramp metaphor):

- `level!(name, n)` / `level(name)` - integer 0..100 effective setting
- Soft zero: `level!(name, 0)` - still ready (powered); not parked
- Transitional alias from shipped `show_percentage!` / `skip_percentage!` /
  `percentage` toward `level!` / `level` (see Next)

Experiment weights (not forced into visible_* or ready_*):

- `variants!(name, hash)` / `variants(name)` - override weights; does not power
- `variant(name, actor)` - assignment when ready

Stats outcomes (while ready / powered only; side effects of `visible?` / `variant`,
not power APIs):

- `shown_count` - evaluations that passed and count as seeing the feature
- `skip_count` - ready evaluations that did not pass (audience/level/group miss)
- `shown_share` - shown_count / (shown_count + skip_count)

`skip_count` stays for soft miss only. It does not mean parked. Do not rename soft
miss to `park_count` or `pause_count`.

Config that stays (different domain):

- `stats_enabled` - master switch for the stats subsystem
- `record_stats:` kwarg on `visible?` / `variant` - inspect without recording

### Power state machine (locked)

Three statuses:

- ready (started) - powered; `visible?` and stats may run
- pending - in YAML registry; no power decision since initialization or clear!
- parked (paused) - hard-off via `park!`; fail closed early; no stats writes

`ready?` / `pending?` / `parked?` are not inverses of `visible?(actor)`. A ready
flag can still yield `visible?` false (soft miss -> `skip_count`). Ready +
`level` 0 stays ready, not pending and not parked.

### clear! (resolved for implementation)

The operator accepted clear! as a reset to pending. Pending means no power
decision since initialization or the latest clear, rather than an immutable
history claim. Split the operations:

- `park!` - explicit parked hard-off (paused)
- `clear!` - wipe runtime overrides and the power decision, restoring pending

clear! starts a new decision period; previous parked or ready decisions are not
retained as the current power state.

### Rejected as primary vocabulary

- enable/disable, on/off, activate/deactivate, turn_on/turn_off
- offer/omit/withhold
- ramp (use level for the dial)
- hold!, kill!
- skip! / skip? as total hard-off (skip feels like jumping one obstacle, not total park)
- entered/close! as power synonyms
- `ready?(name, actor)`, `ready_count`, `group_ready!`
- `ready!(name, groups: ...)` as the primary slice API (replace-kwargs optional later; no silent append mixed with replace)
- `show?` / power `show!` / admin power action `show` as the lasting public surface
- dual permanent public pairs ready/park and start/pause
- body/organism metaphors in contracts

### Why the split

- `show?` collides with authorization policy methods and REST/ActiveAdmin show.
- `skip!` as hard-off sounded like a single bypass, not total off; `park!` fits total pause.
- ready/pending/parked matches board-like power status; start/pause remain glosses.
- `shown_count` / `skip_count` measure evaluation outcomes while ready; they are not power verbs.
- `visible?` pairs with shown stats without claiming authorization.

### YAML contract (locked direction)

Every flag in `config/features.yml` declares identity in git:

- `type` - group | boolean | percentage | actors | experiment; omitting type defaults to group
- type defaults - `level` 0..100, default `groups`, default `actors`, default `variants`
- existing fields stay - `description`, `expires_at`, `conditions`

Unknown names fail closed. Runtime adapter holds powered state and overrides.
Effective settings = DB override if present else YAML default else empty/zero for
that setting. Multi-gate OR across types is not the v1.0 model; one type per flag.

`ready!` is allowed for every type. Type-specific settings still apply: e.g.
percentage flag after `ready!` with YAML `level: 0` is visible to nobody until
`level!(..., n)`.

### Hard-off resource contract (locked)

`park!` means:

1. No audience receives the feature.
2. Runtime settings cleared and power off so evaluation fails closed early.
3. Lowest CPU/memory path on `visible?` (no group membership, no percentage hash, no conditions when not ready).
4. No `shown_count` / `skip_count` writes.

Soft miss (ready, `visible?` false) may still increment `skip_count`.
Soft dial `level!(..., 0)` is not parked.

### Database (locked direction)

Keep table names:

- `onni_features`
- `onni_feature_gates`
- `onni_feature_stat_buckets`

Rename stat columns:

- `enabled_hits` -> `shown_count` (shipped transitional `show_count` moves to `shown_count`)
- `disabled_hits` -> `skip_count`

Do not rename tables to verb-shaped names. Gate storage keys may stay through a
migration window or normalize later. Models: keep `Feature`, `Gate`, `StatBucket`;
chart model becomes VisibilityChart under the resolved implementation choice.

### Admin and host surface (locked direction)

- Buttons and notices: Ready / Park (global power). Optional UI gloss Start / Pause
  only if it maps 1:1 to ready/park and does not invent a second policy API.
- Slice actions: Add group / Remove group; not Show/Skip as power.
- Scopes: all / ready / pending / parked
- Status copy: Ready / Pending / Parked (glosses started / no decision / paused allowed in help text)
- Percentage field labeled for level
- Chart legend and data attributes: shown_count / skip_count
- Page actions and reserved route keys: ready / park (not show / skip / enable / disable for power); flag detail stays a separate feature route
- Host authorization for those page actions: `ready?` / `park?` (breaking vs enable/disable and vs transitional show/skip action names)
- Reserved flag names include ready, park, pending, visible, show, skip as needed for route safety

### Instrumentation (locked direction)

`feature_operation.onni` operation names: `:ready`, `:park`, `:clear` (once clear
behavior is locked), `:visible_group`, `:drop_group`, `:visible_actor`,
`:drop_actor`, `:level` (transitional `:show_percentage` until level wins),
`:variants`.

`stats.record.onni` payload uses shown/skip outcome (`:shown` boolean or
`:outcome`), not `:enabled`, not power `:ready` / `:parked`.

### Compatibility

Implementation decision: the operator chose the direct v1 API and removal of
old names now. The optional 0.x transition below is design history, not the
selected implementation path. Keep the current package version until release.

0.x may expose aliases with deprecation:

- enable/disable family -> ready/park/visible layers
- transitional power `show!` / `skip!` -> `ready!` / `park!`
- transitional `show?` -> `visible?`
- transitional `show_group!` / `skip_group!` / `show_actor!` / `skip_actor!` -> visible_*/drop_*
- transitional `show_count` / `show_share` / payload `:show` -> `shown_count` / `shown_share` / `:shown`
- transitional admin action `show` / `skip` -> `ready` / `park`
- transitional scopes `showing` / `skipped` -> `ready` / `parked` (and add `pending`)
- optional `start!` / `pause!` -> `ready!` / `park!` only as short-lived aliases

v1.0 removes enable/disable and transitional show/skip power and evaluation names
from the published surface. README and AGENTS project blurb use ready/park/visible
and shown/skip stats. Historical docs under reviews/issues/dependencies are not
rewritten wholesale; live issue and RFC get an amendment pass (Next).

Auth reminder stays: `Onni.visible?` answers rollout/experiment visibility, not
authorization. Keep privileged actions behind a real policy layer. Do not name the
evaluation API `show?`.

## Effects

This note records the vocabulary revision and its resolved choices. The
follow-up implementation is tracked in
`docs/issues/20261113091112_ready-park-visible-terminology.md`; that issue owns
execution evidence and current remaining work.

## Next

Resolved product decisions for the follow-up rename:

1. clear! restores pending by clearing the power decision and runtime settings.
2. level!/level is the sole dial API; no percentage read alias.
3. Only level!(name, 0); no drop_percentage! method.
4. Rename the chart class to VisibilityChart.
5. No combined ready! replacement keywords in this revision.
6. Keep skip_count for soft misses.
7. Remove old aliases now, as explicitly selected by the operator.
8. Keep percentage_of_actors as a stored gate key; row renaming stays deferred.
9. Keep per-evaluation counts; request/actor deduplication stays deferred.

Implementation sequencing for the vocabulary revision:

1. Specs that lock ready/pending/parked power vs visible?/shown_count/skip_count.
2. Ruby API: `ready!`, `park!`, `ready?`, `pending?`, `parked?`, `visible?`; slice visible_*/drop_*; dial `level!`/`level`; remove old aliases as selected.
3. Resolve `clear!` vs pending before shipping the power rename.
4. Stat column migration show_count -> shown_count; sampler/buffer/instrumentation payload `:shown`.
5. ActiveAdmin routes ready/park, scopes ready/pending/parked, copy, host policy docs.
6. README / CHANGELOG / docs/changelogs; RFC-0003 amendment; implementation issue update.
7. Pressure ceilings recalibration if hot-path names change.
8. Verify absence of enable/disable and transitional show/skip aliases; prepare the versioned release separately.

Do not treat the first RFC-0003 ship as final vocabulary. Open or extend the
implementation issue before coding this revision.

## Source

- Session design threads: enable/disable replacement; appliance hard-off; YAML
  types; coverage/flag analytics; show/skip; Rails/ActiveAdmin and authorization
  `show?` collision; amkisko/amaaov naming principles; project-management
  ready/pending; ready/park vs start/pause (glosses only, not dual primary);
  rejection of offer/ramp/enable/hold/kill; rejection of skip! as total hard-off;
  rejection of ready_count and ready?(actor); visible? for evaluation;
  shown_count/skip_count for stats; clear! vs pending open.
- Implementation issue: `docs/issues/20261113060000_show-skip-typed-flags.md`
- Vocabulary implementation: `docs/issues/20261113091112_ready-park-visible-terminology.md`
- RFC-0003: `rfcs/0003-show-skip-typed-flags.md` (amend after this vocabulary lock)
- Engineering changelog of first ship: `docs/changelogs/20261113062000_show-skip-typed-flags.md`
- Peer vocabulary researched for contrast (not adopted as primary): Flipper
  enable/disable; LaunchDarkly on/off; Unleash impressions; SimpleCov hit/miss;
  Kanban/SAFe ready/pending/committed/released; Jira to-do/in-progress/done;
  product ship/hold/kill/ramp; IEC/IEEE power states for hard-off resource goals only.
- Docs conventions: `docs/plans/` design notes; five-section note shape; supersede
  in place when a decision changes shape.
- Repository: https://github.com/amkisko/onni.rb
