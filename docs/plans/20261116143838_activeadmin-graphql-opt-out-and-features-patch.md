# ActiveAdmin GraphQL opt-out and Features patch surface

Design-only. Not committed work.

## Participants

Andrei Makarov.

## Decisions

No product decision. This note records exploration from a session about
first-class ActiveAdmin and GraphQL surfaces, whether a host can keep
`activeadmin-graphql` without Onni's operator schema, and whether a host can
patch the Features ActiveAdmin page in full or in parts.

Observed loading contract:

- ActiveAdmin Flags dashboard is a first-class opt-in via
  `require "onni/active_admin"`. That path loads Rails, ActiveRecord, and the
  Features `register_page` through ActiveAdmin `load_paths`.
- ActiveAdmin operator GraphQL is a separate first-class opt-in via
  `require "onni/active_admin_graphql"` plus
  `Onni::Admin::GraphQL.install!(schema)` in the namespace
  `graphql_configure_schema` hook. Documented in RFC-0012 and
  `docs/activeadmin-agent-access.md`.
- A general public-client `onni/graphql` product schema is intentionally not
  shipped. Hosts wire the Ruby evaluation API into their own schemas (see the
  existing GraphQL cookbook plan). Core `require "onni"` stays free of a
  runtime `graphql` dependency.

Observed GraphQL separation from HTML ActiveAdmin:

- Ordinary `onni/active_admin` does not load the GraphQL extension.
- `app/admin/features.rb` calls `Onni::Admin::GraphQL.register_page!(self)` only
  when `Onni::Admin::GraphQL` is already defined.
- Therefore a host can run the HTML dashboard, install host-owned
  `activeadmin-graphql` for its own resources or pages, and omit
  `onni/active_admin_graphql` and `install!`. Onni then adds no `onni` page
  field and no `onni_*` mutations.
- The reverse is not independent: the GraphQL loader requires
  `onni/active_admin`, and the catalogue query field is registered on the
  Features page so it remains available when generic resource queries are
  disabled.

Observed Features customization surface today:

- Host policy: `Onni.configuration.admin_authorized` and the host authorization
  adapter methods for Features page actions (`ready?`, `park?`, `clear?`,
  `feature?`, `update_feature?`, `stats?`; GraphQL also uses `:read`).
- Documented view replacement: host may replace
  `app/views/admin/features/_stats.html.erb` for the statistics section.
- Optional vanity paths via `Onni::ActiveAdminRoutes.draw`; default dashboard
  needs only `ActiveAdmin.routes`.
- GraphQL install is idempotent, preserves unrelated schema fields, and fails
  closed on `onni_*` name collisions. Host schema customization stays in the
  same configure hook.
- There is no documented first-party API to override parts of the Features
  `register_page` DSL (menu, columns, sidebars, page_actions). The page is one
  gem-owned registration file. Host re-registration through ActiveAdmin load
  order is possible in principle but is not a supported patch contract.

Candidate improvement themes raised in the session (not chosen):

1. Document the GraphQL opt-out path explicitly: HTML ActiveAdmin plus host
   `activeadmin-graphql` without Onni operator schema.
2. Define a supported Features patch contract (full re-register guidance,
   and/or named partial override hooks).
3. Later design already noted elsewhere: unify the catalogue onto a root
   SchemaField capability path instead of a Features page field.

## Next

Hold until a product choice. If work starts, open an issue and supersede or
link this plan. Prefer docs-only first if the only gap is discoverability of
the existing opt-out path.

## Source

- Session questions on ActiveAdmin / GraphQL first-class status, GraphQL
  opt-out with `activeadmin-graphql` retained, and Features full/partial patch
- [RFC-0012 ActiveAdmin GraphQL operator API](../../rfcs/0012-activeadmin-graphql-operator-api.md)
- [GraphQL-ruby: no first-class Onni extension](20261113184244_graphql-ruby-no-first-class-extension.md)
- [ActiveAdmin agent-access host DX](../issues/20261116085845_agent-access-host-dx.md)
- [Setup guide](../activeadmin-agent-access.md)
- [README Extensions and Programmatic ActiveAdmin access](../../README.md)
- `lib/onni/active_admin.rb`
- `lib/onni/active_admin_graphql.rb`
- `app/admin/features.rb`
