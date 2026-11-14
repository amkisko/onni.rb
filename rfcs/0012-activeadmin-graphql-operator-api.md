# RFC 0012: ActiveAdmin GraphQL operator API

- Type: Standards Track
- Status: Experimental
- Created: 2026-11-14
- Author: Codex

## Summary

Ship an opt-in Onni schema extension for activeadmin-graphql. Test it together
with activeadmin-device_authorization using the host's bearer authentication.
Keep GraphQL and authentication out of the ordinary Onni core. Require
graphql >= 2.6.15 for the optional surface to include the published security fixes.

## Motivation

The Features page is a custom ActiveAdmin page. Loading GraphQL alongside it
does not create a typed operator API for its catalogue, signals or commands.
Programmatic clients need discoverable inputs and the same domain mutations,
not writes to raw Onni gate/stat tables.

## Guide-level explanation

Install the two optional gems in the host, require onni/active_admin_graphql,
and call Onni::Admin::GraphQL.install!(schema) in the namespace's existing
graphql_configure_schema hook. The host enables its endpoint and dynamic
visibility with preload: false, authenticates before introspection, maps token scopes to named
capabilities onni:read/onni:write, and owns rate limits, consent and token storage.
CLI, MCP and script clients send the same GraphQL JSON requests.

## Reference-level explanation

Query onni exposes features(first: 25, after: String) and feature(name: String!)
return typed operator snapshots. List first is 1..100; after is the last feature
name in ascending name order. List includes only registered catalogue names
and uses one bounded gates batch. It does not record visibility counts.
Feature fields include description, expiry metadata, power, effective audience,
variants, signals, Delivery targeting and evaluation-count policy. Statistics
are a separate bounded field (1..720 hours). Unknown feature reads return null.

Named mutations onni_ready, onni_park, onni_clear, onni_observe,
onni_reset_signals, onni_set_filters, onni_set_experiment_filters,
onni_set_signal_threshold, onni_set_variants and onni_set_stats call the existing
Ruby API and return a fresh typed feature snapshot. No raw table CRUD is exposed.
Inputs use bounded signed 64-bit signal integers, typed audience/stats inputs,
named variant weights and explicit nullable thresholds. Invalid input is a
GraphQL execution/coercion error and never reports successful mutation.

Fields use onni:read or onni:write capabilities plus the namespace authorization
adapter for the existing Features page. Named power actions authorize :ready,
:park or :clear; settings and observations authorize :update_feature. Both field
visibility and execution fail closed. The existing Onni admin_authorized callback
runs against the real request controller. A write capability does not override
a denied host policy. Normal host schemas and hooks remain intact.

Load the extension before ActiveAdmin registrations so the existing Features
page supplies the onni query object even when generic policy/resource queries
are disabled. The extension installs idempotently into the supplied schema; requiring it alone
does not enable routes, choose authentication, add a token store or register raw
ActiveRecord resources. Host-scoped bearer validation and issuance remain host
responsibilities. The test host proves challenge, signed-in consent, single-use
token exchange, absolute/idle expiry, revocation, enabled clients, scopes,
owner policy and introspection. It uses synthetic disposable credentials only.

## Drawbacks

Hosts must configure a real authentication bridge and capabilities. Existing
HTML policy callbacks must be callable from the GraphQL controller as well.
Catalogue and audience identifiers are privileged operator data. Per-feature
ACLs and end-user rollout evaluations are not provided by this admin API.

## Rationale and alternatives

Reuse activeadmin-graphql's namespace and schema hook, typed fields and dynamic
visibility with preload: false. Keep the normal core and ActiveAdmin UI usable without GraphQL.
A general public-client onni/graphql API would have different ownership and is
still not supplied. No separate CLI or MCP server is necessary for this contract.

## Prior art

Onni's Ruby API and ActiveAdmin Features page; activeadmin-graphql custom schema
hook and capabilities; activeadmin-device_authorization host model/bearer contract.

## Unresolved questions

The contract remains experimental pending maintainer release review.
