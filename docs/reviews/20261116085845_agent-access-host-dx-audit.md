# ActiveAdmin agent-access host DX audit

Scope: optional `onni/active_admin_graphql` packaging, host install docs,
capability mapping helper, and Features page authorization contract.

## Participants

Andrei Makarov.

## Decisions

Run claims check against the tree, then a focused engineering pass on the
operator GraphQL ingress path. Skip learned systems, physical actuators, native
UI, and durable-cache modes: none are introduced here. Resource and budget mode
is qualitative only for this docs-and-helper change; no new hot-path evaluation
code. Trace and identification mode notes that the guide already keeps bearer
tokens out of argv and leaves audience identifiers as privileged host-scoped
data. Contract mode covers capability names, page actions, Gemfile floors, and
packaged guide availability.

## Effects

### Claim outcomes

1. README links `docs/activeadmin-agent-access.md` while released 3.0.0 gem
   contents omit `docs/`: supported. Gemspec previously packed only root
   markdown plus `app`/`config`/`lib`/`sig`.
2. `install!` requires visibility preload false: supported in
   `lib/onni/active_admin_graphql.rb`.
3. Loader activates `activeadmin-graphql >= 0.4.1` and `graphql >= 2.6.15`:
   supported. Dual-tree lock mismatch is a host Bundler consequence of those
   activation floors without matching Gemfile pins.
4. Capabilities are `onni:read` / `onni:write`: supported.
5. Catalogue is Features page `graphql_field` with activeadmin-graphql kind
   `:query_page_field`; commands are root `onni_*` Mutation fields: supported
   against activeadmin-graphql 0.4.1 `query_type_pages.rb` and Onni install.
6. GraphQL page actions include read, ready, park, clear, update_feature:
   supported. README previously omitted `clear?` for hosts that only skim the
   dashboard policy paragraph.
7. Host authorization adapters that stringify custom actions: unverifiable in
   this repository; retained as a checklist warning only.

### Pipeline findings

1. High / high / docs: packaged gem could not satisfy the README link. Fix:
   include the guide in `spec.files`.
2. Medium / high / docs: fail-closed host allowlists need explicit page-field
   kind, mutation prefix, and Onni* type rules. Fix: cutover checklist.
3. Medium / high / contract: Gemfile floors lived only in the unpackaged guide.
   Fix: keep floors in the guide, surface them in README install prose, package
   the guide.
4. Low / high / DX: host scope aliasing needed a tiny pure helper. Fix:
   `Access.map_capabilities`.
5. Low / medium / design: root catalogue SchemaField would unify visibility.
   Deferred; page field still matches RFC-0012 when generic queries are off.

No security change to authn, CSRF, or capability fail-closed behavior. No new
actor identifiers. Helper allocates a small array per capability callback.

## Next

Confirm packaging with `gem build` and focused Access plus agent GraphQL specs.
Ship as a patch after review.

## Source

- [Live work](../issues/20261116085845_agent-access-host-dx.md)
- [Setup guide](../activeadmin-agent-access.md)
- [RFC-0012](../../rfcs/0012-activeadmin-graphql-operator-api.md)
