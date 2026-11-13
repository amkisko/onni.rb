# ActiveAdmin Features load path too late

## Participants

Andrei Makarov.

## Dependency

onni (~> 1.0), lockfile onni (1.0.0). Distribution: https://rubygems.org/gems/onni/versions/1.0.0
Previously observed on onni 0.1.3 (`lib/onni/engine.rb`); still present in 1.0.0 `lib/onni/active_admin.rb`.

## Symptom

Production `GET /admin` returns HTTP 500: `NameError: undefined local variable or method 'admin_features_path'`. Named route helpers for the Features page are missing; only `admin_feature` from `Onni::ActiveAdminRoutes.draw` exists.

## Evidence

1. Unpacked onni 0.1.3 appends `app/admin` inside `ActiveSupport.on_load(:after_initialize)` in `lib/onni/engine.rb`. Unpacked 1.0.0 keeps the same hook in `lib/onni/active_admin.rb`.
2. ActiveAdmin `Application#routes` calls `load!` while routes are drawn. `load!` instruments `before_load`, then enumerates `load_paths`. That runs before `after_initialize` in production (no class reload).
3. Host production reported `admin_features_path` undefined and feature route names `["admin_feature"]` only. Local development still showed Features after reload because `load_paths` retained the late append.
4. Regression in this tree: remove the Onni admin path, `ActiveAdmin.unload!`, then `load!` without `before_load` leaves `admin_features_path` missing; with `ActiveAdmin.before_load` the path returns before files are read.

## Suggested fix

Upstream: register the ActiveAdmin path with `ActiveAdmin.before_load` instead of `after_initialize`. Host workaround: the same `ActiveAdmin.before_load` append in a host initializer until a gem release includes the fix.

## Effects

- Fixed in this repository: `lib/onni/active_admin.rb` uses `ActiveAdmin.before_load`.
- Spec `spec/onni/active_admin_load_path_spec.rb` requires the path and `admin_features_path` after unload/load without relying on `after_initialize`.

## Next

- Publish a patch release that includes the `before_load` registration.
- Drop the host `ActiveAdmin.before_load` workaround after upgrading past that release.

## Source

- https://rubygems.org/gems/onni/versions/0.1.3
- https://rubygems.org/gems/onni/versions/1.0.0
- https://github.com/amkisko/onni.rb
- `lib/onni/active_admin.rb`
- `lib/onni/active_admin_routes.rb`
- ActiveAdmin `Application#load!` / `Application#routes` (`before_load` then `files` from `load_paths`)
