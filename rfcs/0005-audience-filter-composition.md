# RFC 0005: Audience filter composition

- Type: Standards Track
- Status: Draft
- Created: 2026-11-13
- Author: Andrei Makarov
- Supersedes: RFC-0003 audience types and destructive park transition

RFC-0006 specifies evaluation statistics and RFC-0007 adds programmatic
definitions alongside the YAML catalogue.

## Summary

Compose audience filters on one power switch. Preserve settings when parking a
flag so the same rollout or experiment can resume without reconstruction.

## Motivation

Exclusive types prevent a group rollout from also using a percentage or actor
filter. Removing runtime settings on park makes temporary stops destructive.
Onni controls rollout visibility; host policies still control authorization.

## Guide-level explanation

Ordinary flags need no type. YAML may set everyone: true, groups, actors,
excluded_groups, excluded_actors, and level. A flag without a positive opener
stays invisible even after ready!. Positive openers are everyone: true, an
include list, or a level. All configured filters must pass. Values within one
include list are alternatives; any excluded match rejects the actor.

Onni.filters!(name, groups: ["beta_testers"], level: 25) configures both filters
atomically without changing power. ready! starts the rollout. park! stops it
while retaining all settings; ready! resumes it. clear! removes overrides and
the power decision, restoring YAML defaults in pending state.

filters! changes only named filters. nil removes a filter, including its YAML
default; [] keeps an explicit empty list. Empty includes match nobody. Zero is
a configured percentage that matches nobody. everyone: false removes the
everyone opener. Excludes alone never open an audience.

visible_group!/drop_group! and visible_actor!/drop_actor! retain their include
meaning. Drops do not deny membership. To exclude a group use
filters!(name, excluded_groups: ["staff"]). To remove the whole include clause,
use filters!(name, groups: nil). No clear-include aliases are needed.

level! and visible_* retain their readying behavior. filters! and variants!
preserve pending, ready, or parked power. Operators can edit a parked rollout
without starting it. Filters and variants are independent: type: experiment
permits assignment, but weights do not open the audience. An experiment also
needs a positive opener, for example groups or everyone: true.

## Reference-level explanation

Evaluate power, expiry, a positive opener, actor requirements, actor include and
exclude lists, percentage, group includes and excludes, then conditions.
Omit absent filters. Require an actor for any configured actor-scoped filter,
including excludes and level: 100. Only everyone with no actor-scoped filters
can pass without an actor. Existing conditions keep their actor-present rule.

variant evaluates the same visibility expression before assigning weights.
It requires an actor, type: experiment, and a positive weight total. It records
one feature-level outcome, never a second visible? evaluation or identity stats.
Buckets retain CRC32 of feature_key:actor_id; changing membership does not
change an actor's bucket. Per-group percentages remain out of scope.

YAML type accepts only experiment when present. Former boolean definitions use
everyone: true; group and actor definitions retain their lists without type;
percentage definitions retain level without type. Experiments add an explicit
audience. Reject old type names at load rather than silently widening them.

filters! accepts only the six named filters, validates the entire change before
writes, and stores one JSON mapping in an audience_filters gate. Runtime filter
values override existing list/percentage gates, then YAML. null masks a YAML
filter. Existing powered, group/actor override, percentage, and variants gate
keys remain readable. Filter composition never interprets mixed gates as OR.

Explicit powered wins over legacy markers. Legacy boolean and audience gates
retain their power interpretation, but now all audience kinds intersect.
Importer accepts supported audience kinds together and keeps boolean-to-power
mapping; it cannot infer an OR expression. Review imported cohorts explicitly.

Successful mutations invalidate the existing request and application gate
caches after the adapter commits. Filter state is derived from registry YAML
and committed gate rows; memory-adapter overrides remain ephemeral.

The admin detail page edits filters independently of power, displays each
active clause, and distinguishes an absent filter from an empty include or
zero percentage. Park and Ready preserve the displayed settings. Invalid
submissions apply no filter changes. Existing host authorization gates remain.

feature_operation.onni adds filters with no identity-bearing filter payload.
Existing slice and level event contracts stay unchanged.

## Drawbacks

This changes YAML, boolean and experiment defaults, mixed-gate evaluation, and
park semantics. Hosts must migrate definitions together with the library.
An AND expression cannot represent arbitrary nested OR experiments.
Excludes may add another scan of configured group callbacks.

## Rationale and alternatives

Separate configuration from power so stopping a rollout is reversible. Keep
clear! for reset. A single atomic filters! update avoids half-applied multi-field
edits. Keep drop_* for removing includes and use explicit exclude fields.
Exclusive types require YAML rewrites; OR across kinds widens mixed audiences.

## Prior art

RFC-0003 already separates power, visibility, and assignment. Its conditions
are AND restrictions. The composition plan extends that model to runtime
audience filters without adding per-actor or per-group statistics.

## Unresolved questions

Maintainer review and release selection remain. Per-group levels and arbitrary
Boolean expressions are deferred. Performance measurements must accompany
implementation; no speed or memory improvement is assumed.
