# ActiveAdmin routes auth contract audit

Scope: Onni ActiveAdmin Features registration, optional vanity draw, and host
install documentation for authentication ownership.

## Participants

Andrei Makarov.

## Decisions

Claims-check the controller-versus-mapper contract against ActiveAdmin 4 beta
and this tree. Run security mode only for the admin ingress boundary already
owned by BaseController and `admin_authorized`. Skip learned systems, physical
actuators, durable cache, and resource/budget measurement: no new executable
hot path beyond a request-spec assertion on an existing controller gate. Trace
and identification: no new identifiers.

## Effects

### Claim outcomes

1. `ActiveAdmin.routes(rails_router)` loads registrations and applies the
   ActiveAdmin router with no official nested-draw hook: supported
   (`ActiveAdmin::Application#routes`).
2. Auth for registered pages runs through `BaseController` and namespace
   `authentication_method`: supported.
3. Features index and page actions are ActiveAdmin registrations drawn by
   `ActiveAdmin.routes`: supported (`app/admin/features.rb`).
4. `Onni::ActiveAdminRoutes.draw` maps `/admin/features/:key` to
   `admin/features#feature` after `ActiveAdmin.routes` for helper and
   controller availability, not for auth inheritance: supported.
5. Mapper placement next to ActiveAdmin routes does not by itself apply
   ActiveAdmin config: supported for this vanity draw; the target controller
   remains the Features page controller.

### Findings

1. Medium / high / docs: README and install notes told hosts to draw after
   `ActiveAdmin.routes` without stating that auth stays on the page controller.
   Fixed in README, generator reminder, and module comment.
2. Medium / high / coverage: forbid examples covered index, stats, ready, and
   park, but not the vanity or query-string feature show paths. Extended the
   existing request example.
3. No route reshape and no new public API. Vanity draw remains optional.

## Next

Focused Features request specs. Include the docs line in the next patch
changelog.

## Source

- [Live work](../issues/20261116090422_activeadmin-routes-auth-contract.md)
- ActiveAdmin `Application#routes` and `BaseController#authenticate_active_admin_user`
