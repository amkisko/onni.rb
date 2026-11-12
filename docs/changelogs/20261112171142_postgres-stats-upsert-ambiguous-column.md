# PostgreSQL stats upsert ambiguous column

## Participants

Andrei Makarov.

## Decisions

- Qualify the existing-row hits column on the ActiveRecord upsert `on_duplicate` RHS with `Onni::StatBucket.table_name`.
- Keep SET assignment targets bare; PostgreSQL rejects table-qualified targets in ON CONFLICT DO UPDATE SET.
- Leave `excluded.updated_at` for the timestamp side.

## Effects

- `lib/onni/adapters/active_record.rb` no longer emits a bare `enabled_hits = enabled_hits + N` / `disabled_hits = disabled_hits + N` fragment that PostgreSQL rejects as ambiguous with `excluded`.
- `spec/requests/sqlite_support_spec.rb` asserts the qualified RHS appears in generated SQL; existing increment behavior still passes on SQLite.
- Version set to 0.1.1; CHANGELOG and README dialect note updated.
- Dependency note: `docs/dependencies/20261112171142_onni-postgres-stats-upsert-ambiguous-column.md`.

## Next

- Deliver 0.1.1: merge to main, then `make release` (gem push, tag, GitHub release).

## Source

- `docs/dependencies/20261112171142_onni-postgres-stats-upsert-ambiguous-column.md`
- `lib/onni/adapters/active_record.rb`
