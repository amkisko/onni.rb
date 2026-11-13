# RFC 0003: Typed flags with ready, park, and visible layers

- Type: Standards Track
- Status: Stable
- Created: 2026-11-13
- Author: Andrei Makarov

## Summary

Separate runtime power (ready/pending/parked), actor visibility (visible?),
audience slice changes (visible_*/drop_*), percentage settings (level), and
evaluation outcomes (shown_count/skip_count). Each YAML flag has one type.

## Motivation

A ready percentage rollout at zero must remain distinguishable from a parked
flag or a flag without a power decision. Visibility must not collide with Rails
show actions or host show? policies. Onni answers rollout visibility, never
authorization; privileged actions require the host's policy layer.

## Guide-level explanation

ready!(name) starts the declared type using effective settings. park!(name)
removes runtime settings and stores explicit parked hard-off. clear!(name)
removes runtime settings and the power decision, restoring pending. Pending
means no decision since initialization or the latest clear, not an immutable
claim that the feature has never run. Repeated commands are idempotent.

ready?/pending?/parked? inspect power without an actor, expiry evaluation, or
stats writes. visible?(name, actor = nil, record_stats: true) evaluates the
current audience, conditions, and expiry only when ready. These predicates are
not inverses: a ready flag may be invisible to an actor.

visible_group!/drop_group! and visible_actor!/drop_actor! change one slice.
Visible-slice mutations ready the flag; drops preserve its current power state,
including pending and parked, while masking defaults with an override.
level!(name, n) sets the integer dial and readies percentage flags, even at zero.
level(name) reads it. variants! changes experiment weights without changing power;
variants reads them and variant assigns an actor only while ready.

## Reference-level explanation

Types are group (default), boolean, percentage, actors, and experiment. A mapping
with only description and expires_at declares a group flag with an empty audience.
It remains invisible after ready! until a matching group is added. Explicit
type: boolean declares a flag visible to everyone when ready. Unknown
types or malformed defaults raise ArgumentError at registry load. YAML percentage
defaults use level (integer 0..100); groups and actors use arrays; variants use
nonnegative integer weights with positive total, or an empty map. Mismatched
mutations raise ArgumentError before writes. Unknown evaluations and power
predicates return false; unknown variant/power_state returns nil; mutations raise
KeyError. Runtime level! accepts integer input and clamps it into 0..100.

The powered gate stores true for ready and false for parked. Without valid power
markers or compatible legacy audience gates, the state is pending. Transitions are:

- pending/ready/parked + ready! -> ready, retaining current overrides
- pending/ready/parked + park! -> parked, removing overrides
- pending/ready/parked + clear! -> pending, removing overrides
- any state + visible slice or level! -> ready
- any state + drop slice or variants! -> same power state

Legacy true boolean or matching-type audience gates remain readable as ready;
a false legacy boolean classifies an otherwise unpowered flag as parked.
Empty legacy gate sets cannot preserve a
distinction never stored and become pending. An explicit powered gate wins.
Table names, model names Feature/Gate/StatBucket, and existing gate storage keys
stay unchanged, including percentage_of_actors. Mixed legacy audience types do
not create an OR. Import validates compatible gates and maps boolean to power.

Effective settings use runtime overrides, then YAML defaults, then empty/zero.
Group/actor JSON-array overrides can mask defaults with an empty list. Parked
and pending evaluation return before audience, conditions, hashing, and stats.
Removing power does not erase historical counters. Expiry narrows visibility
while retaining ready power. Repeated evaluations remain repeated counts.

Stats columns are shown_count/skip_count. The former counts passed evaluations;
the latter counts ready soft misses, never parked state. shown_share is their
fraction, or nil without data. The master switch remains stats_enabled.
Sampler contexts and stats.record.onni payloads use shown: true/false; adapters
accept record_stat(..., shown:) and batches use shown_count/skip_count.
VisibilityChart supplies both outcome series and shown_share to custom partials.
Its name describes visibility history; shown_count names only the positive
outcome. Dashboard navigation uses Flags, and group commands read Add group and
Remove group while retaining visible/drop operation values.

Keep schema upgrades reversible and separate: onni:stats_rename maps
enabled_hits/disabled_hits directly to shown_count/skip_count. Hosts on the
transitional show_count/skip_count schema instead use onni:shown_stats to rename
only show_count. New installs use final columns. Stop old readers/writers before
renaming and coordinate rollback with the matching code. No dual-column runtime.

Admin scopes are all/ready/pending/parked. POST commands ready/park require host
policy ready?/park? when page-action policies are configured; the dashboard
admin_authorized check remains mandatory. GET details retain feature. Reserved
names ready/park/pending/visible/show/skip use the query-key detail route. Status
copy is Ready/Pending/Parked. Forms use level and visible/drop group actions.
Chart attributes use data-onni-shown-count, data-onni-skip-count, and
data-onni-shown-share. Unknown power commands return HTTP 404.

feature_operation.onni operations are ready, park, clear, visible_group,
drop_group, visible_actor, drop_actor, level, variants. Level events use the level
field; actor and group changes retain actor_id/group_name. Publish successful
results after committed state and local cache invalidation.

Remove enable/disable and transitional show/skip methods, Flag/Store evaluation
aliases, and percentage read aliases. No start!/pause! synonyms, drop_percentage!
method, or ready! replacement keywords are included. This amendment supersedes
the initial show/skip vocabulary and its proposed compatibility window.

## Drawbacks

Hosts must update call sites, schema, policies, custom samplers, adapters, and
chart partials together. Existing empty gate sets lose historical power intent;
operators must explicitly park a feature when that distinction matters. The
memory adapter remains ephemeral; definitions restore defaults, not lost overrides.

## Rationale and alternatives

Separate power from evaluation instead of overloading show/skip. Clear resets
the decision instead of duplicating park. Level zero is a soft miss without
another drop-percentage command. Keep storage keys to avoid unrelated gate-row
backfills. Remove aliases instead of publishing permanent synonyms.

## Prior art

The existing adapters, typed registry, and migration source shape provide the
implementation basis. The [revised plan](../docs/plans/20261113054615_show-skip-terminology-v1.md)
records the vocabulary decisions.

## Unresolved questions

Request/actor deduplication, cross-process cache synchronization, and renaming
legacy gate storage keys are deferred. Release scheduling is separate from this
accepted contract.
