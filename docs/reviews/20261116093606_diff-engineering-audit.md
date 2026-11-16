# Diff engineering audit

Scope: uncommitted ActiveAdmin zero-route-lines work, optional vanity draw
hardening, and Features Assignment Delivery labels.

## Participants

Andrei Makarov.

## Decisions

Audit the working-tree diff only. Run product-surface, contract, and security
modes for the admin Features path. Skip durable cache, learned systems,
physical actuators, and measured resource/budget samples: no new evaluation
hot path and no package graph change. Trace and identification: no new
identifiers.

## Effects

### Findings and repairs

1. Medium / high / contract: `path_prefix` turned `route_options[:path]` values
   that already started with `/` into `//...`. Normalize with
   `delete_prefix("/")`. Spec covers `/desk` -> `/desk/features/:key`.
2. Medium / high / contract: root vanity helper name `:feature` collides with
   common host helpers. Use `:onni_feature` for root namespaces; keep
   `admin_feature` for the default admin namespace.
3. Medium / high / coverage: Assignment lacked unit coverage for None,
   Experiment, and Delivery-over-experiment priority. Added Flag assignment
   spec and index assertions for demo/search_v2 labels.
4. Low / medium / resource: wrapping `Flag#delivery?` in `Sync.synchronize`
   would serialize Flags index rows on the global lock while other readers of
   `Delivery.entries` stay unlocked. Left `delivery?` as a plain hash key
   check, matching the Delivery admin partial.
5. Low / high / DX (accepted): optional vanity `ActiveAdminRoutes` remains
   larger than the zero-line default needs. Kept as opt-in sugar; no
   `ActiveAdmin.routes` hook. Deletion is a separate product decision.

### Pipeline notes

Ingress for vanity still targets Features `#feature` only after
`ActiveAdmin.routes` has registered the page. Authz stays on BaseController
and `admin_authorized`. Assignment is reported state for operators; it does
not change power or Delivery selection.

## Next

Focused specs green. Include Unreleased changelog lines in the next patch.

## Source

- Working tree diff on ActiveAdmin routes, Flag assignment, Features views
- [Zero route lines](../issues/20261116092620_activeadmin-zero-route-lines.md)
- [Assignment Delivery](../issues/20261116093400_features-assignment-delivery.md)
