# ActiveAdmin Features load path before routes

## Participants

Andrei Makarov.

## Decisions

Register Onni `app/admin` with `ActiveAdmin.before_load` so Features is present when `ActiveAdmin.routes` calls `load!` during route drawing. Stop appending from `after_initialize`, which runs too late in production.

## Effects

- `lib/onni/active_admin.rb` uses `ActiveAdmin.before_load`.
- Spec covers unload/load without the Onni path already present.
- Host apps can drop a temporary `before_load` workaround after upgrading to the patch that includes this.

## Next

- Cut a patch release for RubyGems consumers still on 1.0.0.

## Source

- `docs/dependencies/20261113143754_activeadmin-features-load-path-too-late.md`
- `lib/onni/active_admin.rb`
- `spec/onni/active_admin_load_path_spec.rb`
