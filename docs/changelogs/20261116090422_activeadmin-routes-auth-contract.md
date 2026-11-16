# ActiveAdmin routes auth contract

## Participants

Andrei Makarov.

## Decisions

Clarify that Features vanity routes keep authentication and authorization on
the ActiveAdmin page controller. Prove the vanity and query-string feature
paths fail closed with `admin_authorized`.

## Effects

- README and install generator describe the controller auth contract.
- `ActiveAdminRoutes` comments match that contract.
- Features request spec covers forbidden vanity and query-string show paths.

## Next

Fold into `CHANGELOG.md` Unreleased for the next patch.

## Source

- [Live work](../issues/20261116090422_activeadmin-routes-auth-contract.md)
- [Engineering review](../reviews/20261116090422_activeadmin-routes-auth-contract-audit.md)
