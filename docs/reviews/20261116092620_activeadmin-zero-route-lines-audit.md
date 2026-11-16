# ActiveAdmin zero route lines audit

Scope: Features dashboard host routing, optional vanity draw, and ActiveAdmin
authz ownership.

## Participants

Andrei Makarov.

## Decisions

Follow ActiveAdmin registration and `ActiveAdmin.routes` for all required
dashboard paths. Treat vanity `/features/:key` as optional sugar only. Reject
auto-hooks on `ActiveAdmin::Application#routes` as invented surface. Keep
security ownership on Features `BaseController` and `admin_authorized`.

## Effects

1. High / high / DX: required vanity draw forced an unnecessary host line.
   Fixed by zero-line default and dummy without draw.
2. Medium / high / contract: vanity `to:` stays Features `#feature` only;
   namespace path comes from ActiveAdmin namespace / `route_options[:path]`.
3. Coverage: page-action request suite without vanity; RouteSet specs for the
   optional one-liner. No parallel auth stack.

Skip durable cache, learned systems, physical actuators, and resource budget
measurement: no new hot-path evaluation code.

## Next

Focused Features and ActiveAdminRoutes specs green. Include Unreleased
changelog for the next patch.

## Source

- [Live work](../issues/20261116092620_activeadmin-zero-route-lines.md)
- ActiveAdmin `Router#page_routes` and `BaseController#authenticate_active_admin_user`
