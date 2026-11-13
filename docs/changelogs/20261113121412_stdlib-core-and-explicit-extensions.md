# Standard-library core and explicit extensions

## Participants

Andrei Makarov (@amkisko), the current operator.

## Decisions

Implement RFC-0004: use Ruby's standard library in the core and load framework
integrations only through explicit extension entry points in the same gem.

## Effects

- Remove the unconditional ActiveSupport runtime dependency and its required
  installation graph for core consumers.
- Replace core blank/empty, date, and elapsed-time helpers with Ruby operations.
  Route logging and instrumentation through configured objects.
- Load persistence with onni/active_record, Rails integration with onni/rails,
  and the dashboard with onni/active_admin. The dashboard includes its required
  integrations; the Rails-only entry keeps the memory adapter until configured.
- Keep schema, table names, event fields, rollout behavior, and cache ownership.
  Register additional adapter factories through Onni.register_adapter.
- Change retention configuration to nonnegative integer seconds or nil. Require
  existing hosts to opt into extensions and convert duration configuration.

## Next

Hosts must add the selected require entries before application initialization
and select the persistent adapter explicitly when needed. The separate Rails
7.2 compatibility-graph advisory assessment is not closed by the core extraction.

## Source

- [RFC-0004](../../rfcs/0004-stdlib-core-and-opt-in-extensions.md)
- [Implementation review and validation](../reviews/20261113121412_stdlib-core-and-extensions.md)
- [Usage and migration instructions](../../README.md)
