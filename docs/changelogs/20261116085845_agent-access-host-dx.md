# ActiveAdmin agent-access host DX

## Participants

Andrei Makarov.

## Decisions

Package the operator host guide with the gem. Document the cutover checklist
hosts need for visibility preload, Gemfile floors, capabilities, page policy
actions, and fail-closed bearer allowlists. Add a scope-mapping helper.

## Effects

- `onni.gemspec` includes `docs/activeadmin-agent-access.md`.
- Guide and README list Gemfile floors, `clear?`, allowlist kinds, and
  `Access.map_capabilities`.
- Focused Access spec covers host-to-onni scope mapping.

## Next

Shipped in 3.0.1.

## Source

- [Live work](../issues/20261116085845_agent-access-host-dx.md)
- [Engineering review](../reviews/20261116085845_agent-access-host-dx-audit.md)
