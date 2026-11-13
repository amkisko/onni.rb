# Audience filter composition

Design proposal. Execution is tracked in the implementation issue linked below.

## Participants

Andrei Makarov.

## Decisions

### Product goal

Replace exclusive one-type-per-flag evaluate with composable audience filters on
one power switch. A single flag may combine a boolean everyone-opener, include
groups, include actors, excludes, and a percentage ramp without a YAML type
rewrite. This is the needed change after prior multi-gate cutover friction.

Contract shape: AND of filters that are set (omit unset clauses). Default
audience closed when no positive opener is set. Not prior-library OR parity:
boolean opener plus include-groups both set means intersection (effectively the
groups clause). World-on GA clears narrowing openers and sets the boolean
opener.

Experiment / `variant` stays a separate assignment API after visibility. Global
percent is not experiment.

### Out of scope: targeted stats

Do not add shown/skip counters per group or per actor inside Onni. Feature-level
`shown_count` / `skip_count` stay operational telemetry for flag evaluate volume.
Per-cohort or per-person breakdown is targeted analytics and product tracking,
not feature-flag analysis. Hosts that need that signal should emit their own
events (or use an analytics stack) with group or actor dimensions they already
own. Onni must not grow identity-keyed or group-keyed stats rows for that job.

### Percentage: global first; per-group later design

Phase 1 (in scope with composition): one global `level` / percent clause ANDed
with other present filters. Mental model: of the actors who pass the other set
filters, keep those under the CRC32 ramp. Hash stays `feature_key:actor_id` so
membership changes do not reshuffle the bucket.

Phase 2 (optional, not required for composition): percentage per group, for
example different ramps for `beta_testers` vs `staff` on the same flag.
Open design questions before any issue:

- Storage: map of group name to level 0..100, plus whether a global fallback
  level exists when the actor matches an include group with no per-group level.
- Multi-membership: actor in two include groups with different levels. Candidates
  are highest level wins, lowest wins, explicit group precedence list, or reject
  overlapping membership at configure time. Default preference to decide later:
  highest level wins (most permissive ramp) unless operators ask for strictest.
- Interaction with boolean opener: boolean alone ignores per-group levels;
  boolean plus groups should still mean intersection, then apply the level rule
  for matched groups.
- UI: per-group level chip beside each include group, not a second global dial
  that fights the map.
- Do not invent per-actor percentage maps in Onni; that is allowlist + analytics
  territory.

### Naming (from dependency analysis)

Do not reuse feature-level `park!` for clearing an include chip. Prefer
`clear_group!` / `clear_actor!` (or keep `drop_*` until excludes ship). First-class
exclude lists need a distinct verb, not a rename of remove-from-include.

### Breaking vs 1.0.1

After removing a former `type: boolean`, a definition without an explicit
opener is invisible even when ready. Set everyone: true during migration.
RFC-0005 rejects old ordinary type names at load rather than ignoring them.
Empty group remains closed. Cross-type mutation errors go away when types are no
longer exclusive for evaluate; optional experiment marker remains for `variant`.

### Performance (design expectation)

Hot path today: registry definition, cached gates, power check, one audience
branch, optional conditions, optional feature-level stats. Parked and pending
still return before audience work.

Expensive unit on audience: registered `Group.member?` callbacks (and any Sync
around the group registry), then actor-id string work and CRC32 for percent,
then optional JSON parse when reading list overrides. The relative cost of stats writes versus an audience branch is unmeasured here; composition does not
add per-group or per-actor stats rows.

Phase 1 cost shape:

- Boolean-opener only: should stay near today's boolean path if filter presence
  is checked with cheap flags or pre-parsed gate snapshot fields, not by
  re-parsing JSON on every `visible?`.
- Typical composed shape (include groups + optional global percent): one group
  scan plus one CRC32. That is the sum of today's separate group and percentage
  probes on one call, not a new asymptotic class.
- Worst composed flag (include groups, include actors, excludes, percent): AND
  short-circuit helps, but a miss that fails late can run several membership
  callbacks. Exclude groups can double membership work versus include-only.
  Bound expected include and exclude group counts in admin UI; do not design for
  dozens of group chips per flag.
- Fail-fast order preference: power and expiry, default-closed opener check, nil
  actor when any actor-scoped filter is set, cheap set membership (actors /
  excludes of actors), percent, then group callbacks last among equals.
- No measured before/after yet. Implementation must add a composed pressure
  probe and compare cpu_s, wall_s, allocated_objects, and peak RSS against the
  current all-features / group / percentage ceilings before claiming budget.

Phase 2 percentage-per-group adds map lookup and a multi-membership rule; still
O(groups on the flag) membership calls, not O(actors). Rejected targeted stats
avoid write amplification and identity-keyed storage growth.

## Effects

This proposal supersedes the open "AND vs OR" fork in the dependency
note: AND filter chips are the chosen contract. RFC-0005 and the implementation
issue record execution, including the additional decision to preserve settings
on park. Implementation evidence belongs in that issue.

## Next

- Follow [the implementation issue](../issues/20261113162937_audience-filter-composition.md)
  and [RFC-0005](../../rfcs/0005-audience-filter-composition.md) for phase 1.
- Keep phase 2 percentage-per-group as design questions on that issue; do not
  block phase 1 on per-group levels.
- Do not schedule targeted / per-group / per-actor stats work.
- Reconcile deferred admin ready-for-everyone and soft type upgrade with chips
  so those tickets do not ship a second parallel path.

## Source

- docs/dependencies/20261113155557_onni-exclusive-audience-types.md
- docs/issues/20261113144038_switch-upstream-improvements.md (deferred
  ready-for-everyone / soft type upgrade)
- onni 1.0.1 evaluate, mutations, and feature-level stats contract
