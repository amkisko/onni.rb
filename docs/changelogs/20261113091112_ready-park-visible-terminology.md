# Adopt ready, park, and visible terminology

## Participants

Andrei Makarov (@amkisko).

## Decisions

Adopt the direct v1 API from the revised plan. Remove enable/disable and
transitional show/skip aliases. Keep the package version for release preparation.

## Effects

Separate ready, pending, and parked power from actor visibility. Make clear!
restore pending and park! retain an explicit hard-off marker. Keep zero levels
ready. Use visible_*/drop_* for audience changes, level!/level for the dial, and
VisibilityChart with shown_count/skip_count and shown_share for evaluation history.

Update admin power routes, scopes, status copy, forms, event operations, sampler
payloads, adapters, generators, signatures, and maintained documentation. Provide
a reversible transitional show_count rename alongside the legacy stats upgrade.
Generate the AGENTS project description through Prayfile.

The 210-example suite, lint/type/locale checks, five-worker coverage, and existing
evaluation/SQLite budgets pass. Paired CPU differences remain below the measured
directional floor; allocations are unchanged. The original review records raw
measurements and unstyled captures. A follow-up
replaces those captures with locally built ActiveAdmin styles, adds asset request
coverage, and records 211 passing examples plus styled browser interactions.
Use Flags consistently in navigation and Add group / Remove group in forms.
The updated review keeps the redirect bridge and host-customization limits.

A later operator decision changes the implicit YAML type to group. Accept
metadata-only declarations, keep their audience empty until groups match, and
retain explicit boolean for global visibility. Update the install template,
README, RFC-0003, and dummy admin fixture. Five failing contract checks precede
the fix; the final suite passes 215 examples and lint checks 92 files. Earlier
resource samples remain attached to their original source snapshots.

## Next

Review and coordinate host upgrades before release. Apply the migration matching
the host's existing schema while old readers and writers are stopped.

## Source

- [Implementation](../issues/20261113091112_ready-park-visible-terminology.md)
- [Contract and verification review](../reviews/20261113091112_ready-park-visible-terminology.md)
- [Upgrade guide](../../README.md#upgrading-to-terminology-v1)
- [Product release notes](../../CHANGELOG.md)
