# GraphQL-ruby: no first-class Onni extension

Design-only. Not committed work.

## Participants

Andrei Makarov.

## Decisions

Do not ship a first-class `graphql-ruby` extension. No `onni/graphql` types,
enums, query fields, or gem dependency on `graphql`. GraphQL schemas stay in the
host. Onni keeps a Ruby evaluation and registry surface that hosts wire into
their own schema.

This follows RFC-0004: stdlib core, with opt-in only for integrations Onni owns
end to end (persistence, Rails lifecycle, ActiveAdmin operator dashboard).
ActiveAdmin is first-class because it is Onni's own operator UI. A GraphQL field
is almost always a product API under host authentication, naming, error codes,
connection types, and exposure policy.

Do not collapse power and audience into a client field named `enabled`. Onni
separates `ready?` / `pending?` / `parked?` from `visible?(name, actor)`. Do not
add an `enabled?` compatibility alias for GraphQL hosts. Do not expose
`ready!` / `park!` / audience mutations on a public client schema without the
host policy layer. Do not treat GraphQL as authorization.

Host cookbook (illustrative; not gem code):

- Catalogue and descriptions for an allowlist enum: iterate
  `Onni::Registry.config` or read `Onni[name].description`. The GraphQL enum is
  a client-safe allowlist, not a dump of every registry name.
- Single flag view: `Onni[name]` (`Onni::Flag`).
- List or filter: `Onni.features`, then select by the allowlist.
- Actor visibility: `Onni.visible?(name, current_user)` or
  `flag.visible?(actor)`. Prefer a GraphQL field named `visible` over `enabled`.
- Registry membership: `flag.exist?` (known in the registry). That is distinct
  from `Onni.exist?` (adapter row).
- Power for admin or debug schemas only: `flag.ready?` / `pending?` / `parked?`.
- Experiment arm when the client needs the arm, not a boolean:
  `Onni.variant(name, actor)`.
- Stats: inspect and list resolvers should pass `record_stats: false`. Product
  gates that decide UI may use the default recording policy.
- Unknown names fail closed in the host (false or a typed host error). Do not
  raise through the public query unless the host chooses that contract.

Revisit a gem extension only when multiple independent hosts share the same
schema contract (field names, allowlist mechanism, stats policy) and
copy-pasted resolvers become a measured cost. Prefer a documented recipe or a
tiny host-owned concern over types that subclass `GraphQL::Schema::Object`.

## Effects

No gem code, branch, or changelog from this note. README may point here under
Extensions so hosts find the cookbook.

## Next

Keep GraphQL integration in host apps. Open an issue only if a measured gap
appears that the Ruby API cannot cover for shared hosts.

## Source

- [RFC-0004: Standard-library core and opt-in extensions](../../rfcs/0004-stdlib-core-and-opt-in-extensions.md)
- [README: What Onni is not for](../../README.md)
- [lib/onni/flag.rb](../../lib/onni/flag.rb)
- [lib/onni.rb](../../lib/onni.rb) (`visible?`, `features`, `exist?`)
