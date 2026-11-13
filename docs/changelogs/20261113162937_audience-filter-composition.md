# Audience filter composition

Included in gem cut 2.0.0.

## Participants

Andrei Makarov (@amkisko)

## Decisions

Implement RFC-0005 so an operator can combine a cohort, actor list, excludes,
and a percentage on one flag, then park and resume the same settings. Keep
clear! as reset. Replace ordinary exclusive YAML types with explicit filters.
Require experiments to declare an audience before assigning variants.

## Effects

The runtime and admin editor support independent audience clauses and preserve
settings on park. The implementation issue holds the claim audit, before/after
spec evidence, persistence checks, visual assessment, and performance samples.
The README and install template describe migration from the former types.
Cut under `## 2.0.0 (2026-11-13)`.

## Next

Deliver with `make release`. Hosts migrate YAML and call sites with the upgrade.

## Source

- [RFC-0005](../../rfcs/0005-audience-filter-composition.md)
- [Implementation and evidence](../issues/20261113162937_audience-filter-composition.md)
