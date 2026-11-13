# Prior-library cutover and host helpers

## Participants

Andrei Makarov.

## Decisions

Ship ActiveAdmin `before_load` with a generic prior-library cutover path for the next patch: SQL table migrate source, README checklist, safer install-generator stats defaults, and `onni/rspec`. Do not name other feature-flag gems in the public API or README. Defer admin ready-for-everyone UI and a dedicated type soft-upgrade API; document group-to-boolean cutover in the README instead.

## Effects

- `Onni::Migrator::ActiveRecordTables` reads two configured feature/gate tables.
- README cutover checklist covers type choice, OR vs one type, actor ids, unsupported prior gates, and stats defaults.
- Install template enables `stats_buffer` and `stats_sample_rate = 0.1` with ActiveAdmin route and Tailwind reminders.
- `require "onni/rspec"` then `Onni::RSpec.install!` resets memory adapter and request store.

## Next

- Delivered into cut 1.0.1; publish via `make release`; hosts drop ActiveAdmin `before_load` workaround after upgrade.
- Later: admin UX when Ready on empty group flags; optional soft type-change helpers.

## Source

- `docs/issues/20261113144038_switch-upstream-improvements.md`
- `docs/dependencies/20261113143754_activeadmin-features-load-path-too-late.md`
- `lib/onni/migrator/active_record_tables.rb`
- `lib/onni/rspec.rb`
- `lib/onni/active_admin.rb`
