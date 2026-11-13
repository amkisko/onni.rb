# Switch upstream improvements

## Participants

Andrei Makarov.

## Decisions

Release scope for the next patch: ActiveAdmin `before_load` registration (already fixed in tree) plus a generic prior-library cutover path (SQL table source + README checklist). Do not name other feature-flag gems in public API or docs. Do not restore enable/disable aliases. Do not turn Onni into an authorization layer.

Defer to later work: admin "Ready for everyone" control for empty group flags; runtime soft type upgrade API; deeper generator route/Tailwind patching beyond install reminders.

## Effects

- Fact-checked against current tree and a common prior-store table shape (features key column; gates feature_key/key/value).
- `boolean` -> `powered` already exists in `Migrator::Importer`.
- Default YAML type is `group`; `ready!` alone does not mean visible to everyone.
- Prior OR across boolean and groups is one type in Onni; cutover must pick a type per flag.
- Time-based percentage gates have no Onni gate; import skips unsupported keys.
- Prior actor values often differ from `Onni::Actor.id` (`Class;id` unless `feature_actor_id`).

## Next

- Cut 1.0.1 includes ActiveRecordTables, cutover README, install defaults, and `onni/rspec`; publish via `make release`.
- Later: admin ready-for-everyone UX; document or add group->boolean soft upgrade without gate loss.

## Source

- Host switch notes (this session)
- `lib/onni/migrator/importer.rb`
- `lib/onni/active_admin.rb`
- `lib/generators/onni/templates/initializer.rb.tt`
