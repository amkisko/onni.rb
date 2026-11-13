# Onni exclusive audience types vs filter composition

## Participants

Andrei Makarov.

## Dependency

Released baseline: onni 1.0.1 (this repository; Gemfile.lock pins onni 1.0.1). Consumer constraints were not supplied or checked. This note describes the baseline before the RFC-0005 working-tree changes. Evaluation audience is a single `case` on YAML type. Registered types: boolean, percentage, group, actors, experiment. Default YAML type when omitted: group.

## Symptom

After cutover from a prior multi-gate OR store, the exclusive one-type-per-flag model is hard to justify for operators. They ask why a boolean flag cannot also take groups or a percentage ramp the way prior stores ORed gates, instead of forcing a type rewrite or a second flag for the same product intent. Experiment versus percentage raises the same composition question. Product docs name the types and state that evaluation never ORs audience kinds, but they do not explain why composition is refused when power is already shared and YAML conditions already AND-narrow after the audience match.

## Evidence

Checked against onni 1.0.1 evaluate and mutation contracts:

- Power (`ready!` / `park!`) is shared across types. Cross-type mutations raise (`visible_group!` needs group; `level!` needs percentage; `variants!` needs experiment; actor mutations need actors).
- After powered and not expired, audience is one type branch with no OR across kinds:
  - boolean: audience always matches (actor optional for that branch).
  - group: actor required; true only if the actor is in one enabled group.
  - actors: allowlist of actor ids. Nil actor yields a nil id and fails the include check (fail closed), without the explicit actor-required guard used by group and percentage.
  - percentage: actor required; CRC32 bucket under level 0..100 (single on/off ramp).
  - experiment: audience matches when variant weights sum positive, with no actor required on that branch. Assignment is CRC32 into named weights. `variant` returns nil without an actor. So `visible?` without an actor can still be true for a ready experiment with positive weights; `variant` cannot.
- Product docs: one type per flag; evaluation never ORs different audience types. Cutover checklist for a prior store that ORed boolean and groups: pick one type; early-access then everyone means change YAML to boolean (stored group gates are ignored by boolean evaluate). Public docs avoid naming the prior gem.
- Partial composition already exists as YAML `conditions` (AND after audience match when an actor is present). Nil actor skips conditions (treats them as met). Conditions are not a runtime dial: you cannot `visible_group!` into a boolean flag; group membership on boolean is only a static YAML narrow; nil-actor paths still see a ready boolean as world-on.
- `drop_group!` / `drop_actor!` remove one value from the include override. They are not deny filters. Feature-level `park!` clears overrides and stores hard-off. Empty group audience stays closed when ready (aligned with a default-closed audience, unlike ready boolean).
- The exclusive split is a published product contract. The adapters accept generic gate rows; exclusivity is enforced in evaluation and mutations. An opacity rationale for the original choice was not established by this review. A composed filter model could cover the same intents on one flag without a type rewrite. The cost of exclusivity is operator confusion and migrate/YAML churn when widening from cohort to everyone or when mixing ramp with cohort.

Operator testimony this session:

- Many cutover flags stay `type: group` with a cohort group such as `beta_testers`. GA path today is widening that group set or changing YAML to boolean. Neither needs a hybrid under the current model.
- A logged-in cohort group is not boolean world-on (nil actor).
- Experiment is intentional named A/B buckets, not a performance tool.

## Suggested fix

Preferred direction (Andrei): ActiveAdmin-style filters on one power switch. Only filters that are set enter the expression. Default audience gate is closed: if no positive opener is set, `visible?` is false even when ready. No exclusive YAML `type` required for ordinary evaluate. Keep an optional experiment/variant marker when assignment is needed.

Canonical expression (omit any clause whose filter is unset):

```
powered
AND boolean_opener?          # only if boolean filter is set (clause always true for that filter)
AND (g1 OR g2 OR ...)        # only if include-groups are set
AND (a1 OR a2 OR ...)        # only if include-actors are set
AND NOT (xg1 OR xg2 OR ...)  # only if exclude-groups are set
AND NOT (xa1 OR xa2 OR ...)  # only if exclude-actors are set
AND percent?                 # only if percent filter is set
```

Rules:

- Unset filter => that clause is absent, not false.
- Default closed => at least one positive opener must be set (boolean opener, include-groups, include-actors, or percent). Exclude-only does not open the gate.
- Boolean set => everyone-opener clause (actor optional for that clause alone). Boolean unset => omit; groups or percent alone can open.
- When boolean opener and include-groups (or include-actors, or percent) are both set, AND means the intersection. World-on GA is boolean opener with other positive openers cleared, not boolean left ANDed with leftover cohort groups. This is filter composition, not prior-library OR parity.
- Include groups/actors: OR within the filter, AND with other present filters.
- Exclude groups/actors: first-class deny filters. AND NOT (any excluded match). Today's `drop_group!` / `drop_actor!` only remove an include; they are not deny filters.
- Naming: do not reuse feature-level `park!` for clearing an include chip. `park!` already means hard-off and clear overrides. Prefer a clear-include verb that cannot be read as power park (for example `clear_group!` / `clear_actor!`), or keep `drop_*` until a dedicated exclude API exists. First-class exclude chips need a distinct verb or list API, not a rename of remove-from-include.
- Percent set => CRC32 ramp clause. Percent unset => omit (not "0%").
- Variants: assignment API after visibility; percent is not experiment.
- Nil actor fails closed when any actor-scoped filter (include/exclude group or actor, or percent) is present. Nil actor may still pass when only the boolean opener is set.
- Breaking vs 1.0.1: ready boolean without any opener filters would become invisible under default-closed; callers that rely on type boolean world-on need an explicit boolean opener. Experiment `visible?` without actor would fail closed once actor-scoped filters or a stricter nil-actor rule apply.

UI/API metaphor: add/clear filter chips rather than a type enum. Optional YAML contract only if call sites need an experiment/`variant` marker.

GA from early access under the AND model: set the boolean opener and clear include chips that should no longer narrow; keep excludes or percent only if still wanted. No `type: boolean` rewrite.

Gap in onni 1.0.1: evaluate is still a single type `case`; `drop_*` are remove-from-include, not exclude filters; empty group stays closed but boolean cannot compose with groups or percent on one flag.

Consumers until upstream changes: keep declaring `type: group` in feature YAML; do not invent hybrids.

## Next

- Chosen contract: AND filter chips (not prior-library OR). Design plan:
  docs/plans/20261113160847_audience-filter-composition.md.
- Phase 1 is tracked in
  [the implementation issue](../issues/20261113162937_audience-filter-composition.md)
  and [RFC-0005](../../rfcs/0005-audience-filter-composition.md). The implementation
  also changes park to preserve settings, which composition alone would not fix.
- Phase 2 design only: percentage per group (multi-membership rule TBD). Do not
  block phase 1 on it.
- Out of scope: stats per group or per actor (targeted analytics, not flag
  analysis). Keep feature-level shown/skip only.
- Until a release contains that implementation: consumers stay on group plus a cohort group such as
  `beta_testers`; GA widens groups or changes type to boolean only when
  actor-free visibility is required.
- Reconcile deferred admin ready-for-everyone and soft type upgrade with chips
  so those do not ship a second path.

## Source

- This repository at onni 1.0.1: evaluate, mutations, conditions, actor hashing, registry type list, README one-type and cutover checklist, RFC typed-flags contract
- Operator cutover testimony this session (generic; no private product names)
- Related: docs/issues/20261113144038_switch-upstream-improvements.md
- Design plan: docs/plans/20261113160847_audience-filter-composition.md
