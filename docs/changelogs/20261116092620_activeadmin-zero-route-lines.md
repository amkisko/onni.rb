# ActiveAdmin zero route lines

## Participants

Andrei Makarov.

## Decisions

Make the Features dashboard usable with only `ActiveAdmin.routes`. Keep vanity
draw optional and locked to the Features page controller.

## Effects

- Dummy and README no longer require `Onni::ActiveAdminRoutes.draw`.
- Namespace-aware optional vanity draw.
- Request specs cover page-action authz without vanity; RouteSet specs cover
  the one-liner.

## Next

Shipped in 3.0.1.

## Source

- [Live work](../issues/20261116092620_activeadmin-zero-route-lines.md)
- [Engineering review](../reviews/20261116092620_activeadmin-zero-route-lines-audit.md)
