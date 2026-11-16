# ActiveAdmin routes auth contract

## Participants

Andrei Makarov.

## Decisions

Keep Features dashboard paths on ActiveAdmin registration so
`ActiveAdmin.routes` draws them on BaseController. Keep
`Onni::ActiveAdminRoutes.draw` as an optional vanity URL to the same feature
page action. Document that authentication and authorization live on that
controller contract, not on mapper placement next to or under an admin
namespace. Do not invent a wrapper that nests gem routes inside
`ActiveAdmin.routes`.

## Effects

README, install generator, and `ActiveAdminRoutes` module comments state the
controller auth contract. The Features request spec forbids both the vanity
path and the query-string feature path when `admin_authorized` fails.

## Next

Shipped in 3.0.1. Host wiring defaults continue under
[zero route lines](20261116092620_activeadmin-zero-route-lines.md): vanity draw
stays optional; dashboard needs no Onni `routes.rb` line. Authz ownership on
the Features controller remains.

## Source

- [Engineering review](../reviews/20261116090422_activeadmin-routes-auth-contract-audit.md)
- [Changelog draft](../changelogs/20261116090422_activeadmin-routes-auth-contract.md)
- `lib/onni/active_admin_routes.rb`
- `app/admin/features.rb`
