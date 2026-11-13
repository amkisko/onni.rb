# Audience filter composition

Working-tree implementation draft; no release has been cut.

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

## Next

Review the breaking contract and select an appropriate release. Do not publish
this change as an unchanged-contract patch.

## Source

- [RFC-0005](../../rfcs/0005-audience-filter-composition.md)
- [Implementation and evidence](../issues/20261113162937_audience-filter-composition.md)
