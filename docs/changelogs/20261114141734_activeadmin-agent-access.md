# ActiveAdmin programmatic operator access

## Participants

Andrei Makarov.

## Decisions

Implement RFC-0012 as an optional ActiveAdmin operator schema. Keep public-client
rollout evaluation schemas host-owned. CLI, MCP, curl and scripts can use the
same GraphQL endpoint; no separate CLI or MCP server is introduced.

## Effects

Add onni/active_admin_graphql with typed catalogue pagination, individual feature
snapshots, audience and experiment targeting, signals and evaluation buckets.
Add named power, settings, observation and reset commands over the Ruby API.
Use host capabilities and Features page authorization for discovery and execution.
Keep GraphQL and device authorization outside the ordinary core runtime graph.

Test the published GraphQL/device authorization packages together through device
challenge, consent, single-use token exchange and authenticated GraphQL requests.
Cover read-only scopes, host denial, expiry, revocation, CSRF, malformed inputs,
exact integers, bounded reads and non-counting operator queries. Verify actual
curl transport. Require GraphQL >= 2.6.15 for the optional extension.

Document the host-owned bearer bridge and secure credential transport. Preserve
host schema fields and fail before partial installation on command collisions.
Keep the original three-table Delivery benchmark fixture separate from added
identity fixtures; retain its performance ceilings and the failed comparison.
Resource increases and compatibility limitations are recorded in the review.

## Next

Folded into the unpublished 3.0.0 cut. Commit the revised cut, then
`make release`. Adopt the experimental contract in a host with its real
authentication and client tooling.

## Source

- [RFC-0012](../../rfcs/0012-activeadmin-graphql-operator-api.md)
- [Setup guide](../activeadmin-agent-access.md)
- [Engineering review](../reviews/20261114141734_activeadmin-agent-access-audit.md)
- [Live work](../issues/20261114131240_activeadmin-graphql-device-access.md)
