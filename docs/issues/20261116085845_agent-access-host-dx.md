# ActiveAdmin agent-access host DX

## Participants

Andrei Makarov.

## Decisions

Treat cutover difficulty as documentation and packaging debt in this library, not
as a runtime defect in the operator schema. Package the agent-access guide in
the gem. Document Gemfile floors, visibility preload, capability mapping, page
policy actions, fail-closed bearer allowlists, and authorization-adapter symbol
resolution. Add `Access.map_capabilities` for host scope aliases. Leave the
catalogue as a Features page field for now; record root-field unification as a
later design choice.

## Effects

Gemspec includes `docs/activeadmin-agent-access.md`. The guide gains a host
cutover checklist. README policy lists include `clear?` and point at the
packaged guide. Capability mapping helper and focused specs land under
`Onni::Admin::GraphQL::Access`.

## Next

Shipped in 3.0.1. Revisit a root catalogue field with the same SchemaField
capability path only if a second host still needs page-field allowlist
exceptions after the checklist.

## Source

- [Setup guide](../activeadmin-agent-access.md)
- [RFC-0012](../../rfcs/0012-activeadmin-graphql-operator-api.md)
- [Engineering review](../reviews/20261116085845_agent-access-host-dx-audit.md)
- [Changelog draft](../changelogs/20261116085845_agent-access-host-dx.md)
