# ActiveAdmin zero route lines

## Participants

Andrei Makarov.

## Decisions

Default ActiveAdmin host wiring needs no Onni `routes.rb` line. Features
dashboard paths stay on ActiveAdmin `register_page` / `page_action` drawn by
`ActiveAdmin.routes`. Keep `Onni::ActiveAdminRoutes.draw` as an optional
one-liner vanity path that always targets the Features page controller. Do not
prepend or wrap `ActiveAdmin.routes`.

## Effects

Dummy routes drop the vanity draw. Request specs use page-action paths.
`ActiveAdminRoutes.draw` resolves namespace path and Features controller from
ActiveAdmin. README and install generator describe zero lines default.

## Next

Shipped in 3.0.1.

## Source

- [Engineering review](../reviews/20261116092620_activeadmin-zero-route-lines-audit.md)
- [Changelog draft](../changelogs/20261116092620_activeadmin-zero-route-lines.md)
- [Prior auth contract](20261116090422_activeadmin-routes-auth-contract.md)
