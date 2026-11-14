# ActiveAdmin GraphQL and device-authorized access

## Participants

Andrei Makarov.

## Decisions

Test the published activeadmin-graphql 0.4.1 and
activeadmin-device_authorization 0.2.0 alongside Onni. Package SHA-256 values
match RubyGems metadata. Their executable library sources match the inspected
sibling checkouts. Add them only as development/test dependencies; the standard
library core keeps zero runtime dependencies.

Implement RFC-0012 as an explicit Onni ActiveAdmin schema extension. Reuse the
host namespace, authentication, capability hook and authorization adapter.
Expose typed, bounded queries and named commands over existing Ruby mutations.
Test the full device challenge, consent, token exchange and GraphQL HTTP path
with real fixture records. Host authentication remains host-owned. CLI/MCP/curl
and scripts are clients of the same endpoint, not separate Onni servers.

Use test-only owner/client/grant/token models and a bearer bridge in the dummy
host. No production host credentials or live service are used. Keep incoming
release preparation changes intact. Compare the dependency graph/boot/artifact
resources against an isolated copy of the pre-task working tree.

Allow-raise decision for the new optional capability: add its measured 16407
lib/app/sig bytes to the memory Delivery source ceiling, from 148000 to 164407.
Keep all CPU, wall, latency, RSS, storage and correctness ceilings unchanged.
The durable source ceiling already accommodates 160193 bytes and stays unchanged.
This is a scope allowance, not a performance optimization or a new cooker episode.

## Effects

Implement the optional typed schema and real device-authorized test host.
Complete iterative contract, boundary, dependency and resource review. The
engineering review owns the findings, exact validation commands and measured
numbers. Restore the core pressure fixture boundary without raising performance
limits. Add a setup guide with host authentication and credential-safe curl.

## Next

Local implementation and validation are complete. The unpublished 3.0.0 cut
now includes this payload. Commit the revised cut, then `make release`. Real
host adoption (authentication, consent, client tooling) remains after publish.

## Source

- [RFC-0012](../../rfcs/0012-activeadmin-graphql-operator-api.md)
- [Setup guide](../activeadmin-agent-access.md)
- [Engineering review](../reviews/20261114141734_activeadmin-agent-access-audit.md)
- [Engineering changelog](../changelogs/20261114141734_activeadmin-agent-access.md)
- [GraphQL gem](https://rubygems.org/gems/activeadmin-graphql)
- [Device authorization gem](https://rubygems.org/gems/activeadmin-device_authorization)
- [Earlier public-client GraphQL decision](../plans/20261113184244_graphql-ruby-no-first-class-extension.md)
