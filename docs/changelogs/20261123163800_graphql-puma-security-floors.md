# GraphQL and Puma security floors

## Participants

Andrei Makarov.

## Decisions

Raise the optional GraphQL operator floor from 2.6.15 to 2.6.16 and resolve
Puma to 8.1.2 or newer in every development lockfile so advisory scans stay
clean on the supported graphs.

## Effects

- onni.gemspec and onni/active_admin_graphql require graphql >= 2.6.16
- Development puma floor is >= 8.1.2
- Host docs (README, activeadmin-agent-access) match the new GraphQL floor
- CHANGELOG Unreleased names the GraphQL host contract change
- `make audit` exit 0 on non-skipped locks; GraphQL request specs 33/0

## Next

None for this bump. Rails 7.2 scan skip remains a separate decision.

## Source

- docs/issues/20261123163709_lockfile-security-bumps.md
- docs/dependencies/20261123163707_graphql-2616-security-advisories.md
- docs/dependencies/20261123163708_puma-812-security-advisories.md
