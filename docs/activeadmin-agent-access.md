# ActiveAdmin operator access for programs and agents

Onni can extend an activeadmin-graphql namespace with a typed operator schema.
CLI tools, MCP adapters, curl and Ruby scripts can send the same GraphQL JSON
requests. Onni supplies the feature catalogue and commands; the host owns
identity, device consent, token storage, authentication and authorization.

## Install and configure

```ruby
# Gemfile
gem "activeadmin", "4.0.0.beta23"
gem "activeadmin-graphql", "~> 0.4.1"
gem "graphql", ">= 2.6.15", "< 3"
gem "activeadmin-device_authorization", "~> 0.2.0"
gem "onni", require: "onni/active_admin_graphql"
```

Load the extension before ActiveAdmin registrations and route drawing. Ordinary
`require "onni"` and `require "onni/active_admin"` do not load the GraphQL
extension. The standard-library core retains zero runtime dependencies.

```ruby
# config/initializers/active_admin.rb
ActiveAdmin.setup do |config|
  config.namespace :admin do |admin|
    admin.graphql = true
    admin.authentication_method = :authenticate_admin_or_agent!
    admin.current_user_method = :current_admin_or_agent
    admin.graphql_visibility = {preload: false}
    admin.graphql_capabilities = ->(context) { context[:current_user].scopes }
    admin.graphql_configure_schema = lambda do |schema|
      Onni::Admin::GraphQL.install!(schema)
    end
  end
end
```

The example names host-provided authentication/current-principal helpers;
Onni does not define them. They must retain normal admin sign-in for the UI
and consent, and use validated bearer authentication for the GraphQL route.
The example expects the authenticated host principal to expose the scopes of
this request's validated token. The host may instead map its own permission
names to `onni:read` and `onni:write`. Keep any existing schema customization in
the same hook. Installation preserves unrelated fields and can be called again.
Name collisions fail before any Onni command is added.

`preload: false` allows the hook to add a mutation root after the namespace has
configured visibility. With a capability callback, activeadmin-graphql uses
per-request dynamic visibility. Use its resource opt-in settings when the
namespace should expose only explicitly registered host resources; Onni does
not register raw feature, gate or stat tables as editable resources.

## Authenticate the transport

Configure the device gem's host models, scopes, trusted verification origin,
rate limits and consent routes using its
[host contract](https://github.com/amkisko/activeadmin-device_authorization.rb#setup).
Use the normal signed-in admin session for consent. A program requests a device
challenge, asks the person to approve it, then polls for a short-lived token.

The device gem does not install the host's bearer authentication bridge. Before
GraphQL runs, including introspection, that bridge must:

1. Digest the presented bearer using the device configuration's `digest`.
2. Find its token through the allowed enabled-client/resource-owner relation.
3. Reject missing, invalid, revoked, absolute-expired or idle-expired credentials.
4. Check the owner is active and the request has the required read scope.
5. Update `last_used_at` after successful authentication and expose a principal
   with the token's scopes to the namespace.

Return 401 for invalid credentials and 403 for an authenticated token lacking
the endpoint's required scope. Keep normal browser authentication for the UI
and the consent page. A token's write scope does not replace the host's page
policy or `Onni.configuration.admin_authorized`.

For cookie-free bearer clients, validate the bearer before Rails' CSRF check and
skip that check only after the bridge has established a valid bearer identity.
For example, on `ActiveAdmin::GraphqlController`, the host can prepend its
idempotent authentication callback and condition `skip_forgery_protection` on
its validated bearer marker. The presence of an Authorization header alone
is not proof. Keep CSRF protection for cookie/session requests. The integration
specs test bearer access with CSRF protection enabled and invalid-token rejection.

The test host in `spec/support/agent_access.rb` and the dummy models demonstrate
the complete three-gem path with synthetic credentials. Its permissive rate
limit callbacks and stubbed signed-in consent owner are test fixtures, not
production authentication or abuse policies.

## Discover and read

Authenticate first, then use normal GraphQL introspection. `onni:read` permits
the `onni` query object. `onni:write`, together with read permission and the host
policy, permits named commands. Fields denied by capability or policy are absent
from that caller's schema and remain checked at execution.

```graphql
query Catalogue($first: Int!, $after: String) {
  onni {
    features(first: $first, after: $after) {
      items {
        name
        description
        type
        power
        expires_at
        expiration_status
        signals { key level threshold }
        experiments { name filters { groups level } }
      }
      next_cursor
      total_count
    }
  }
}
```

Use `first` in 1..100, default 25. Pass `next_cursor` as `after` for the next
page; it is the last returned feature name in ascending name order. The host's
complexity/depth limits also apply. A page uses one bounded adapter gate batch.
For one item, use `onni { feature(name: "new_checkout") { name power } }`.
Unknown names return null. Reads do not evaluate visibility or record shown/skip.

Snapshots also expose effective audience filters, variant weights, expiry
verification opt-in, conditions and evaluation-count settings. `type: experiment`
means assignment-only variants; `experiments` lists executable Delivery paths.
`statistics(hours: 24)` reads evaluation buckets, limited to 1..720 hours.
This is privileged operator data, including audience identifiers where present.
Control who receives it and include that scope in consent.

## Issue commands

```graphql
mutation ParkCheckout {
  onni_park(name: "new_checkout", reason: "operator") {
    name
    power
  }
}
```

Other commands are `onni_ready`, `onni_clear`, `onni_observe`,
`onni_reset_signals`, `onni_set_filters`, `onni_set_experiment_filters`,
`onni_set_signal_threshold`, `onni_set_variants` and `onni_set_stats`.
Their typed arguments are discoverable through introspection. They call the
existing Ruby mutations and return a fresh state snapshot. They do not run host
Delivery bodies or provide raw record CRUD.

Power commands authorize the Features page's `ready`, `park` or `clear` action.
Settings and observations authorize `update_feature`. Reads authorize `read`.
The existing Onni admin callback runs against the actual request controller.
Keep the normal host policy methods for these actions.

`OnniSignedInteger` accepts signed 64-bit integers. Send decimal strings for
values beyond a client's exact numeric range. Floats, malformed strings and
out-of-range values are rejected. `onni_set_signal_threshold` requires an
explicit `threshold`; pass null to disable automatic parking. Resetting a signal
keeps power unchanged. Clearing overrides keeps retained signal levels.

Invalid commands return GraphQL errors with `INVALID_INPUT` or `NOT_FOUND`
where applicable. GraphQL validation errors also prevent execution. A 200 HTTP
response can therefore contain operation errors; clients must inspect `errors`
before reporting success. Expired/invalid authentication still fails at HTTP.

## Send from curl or an adapter

Write the operation document without credentials:

```sh
cat > tmp/onni-query.json <<'JSON'
{"query":"{ onni { feature(name: \"new_checkout\") { name power } } }"}
JSON
```

Pipe the stored token through stdin. This macOS example assumes it was already
stored under the Keychain service `onni-agent`; use the host's credential helper
on other platforms. The bearer value never becomes a curl argument.

```sh
security find-generic-password -s onni-agent -w |
  ruby -rjson -e 'token = STDIN.read.strip; abort "Missing token" if token.empty?; puts "header = #{JSON.generate("Authorization: Bearer #{token}")}"' |
  curl --fail-with-body --silent --show-error --config - \
    --header 'Content-Type: application/json' \
    --data-binary @tmp/onni-query.json \
    https://onni.rails.fi/admin/graphql
```

An MCP adapter or CLI can use the same documents, variables and header transport,
keep the credential in its secret store, and relay GraphQL operation errors.
This change tests the HTTP contract and a real curl client; it does not ship or
certify a particular MCP server or CLI product.
