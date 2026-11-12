# SQLite full support

Intent: treat SQLite as a first-class ActiveRecord dialect for Onni, not an incidental dummy default.

## Participants

Andrei Makarov (@amkisko)

## Decisions

- Replace dummy `:memory:` with `db/test.sqlite3` plus `timeout: 5000` so pool checkouts share one schema and wait on locks.
- Keep stats upsert on `excluded.updated_at` with conflict target `%i[feature_key period period_start]` (matches `index_onni_feature_stats_unique`).
- Document file-vs-memory, `timeout`, WAL, and `VACUUM` for SQLite hosts; keep other-dialect override note for non-`excluded` SQL.

## Effects

- Dummy and CI AR paths no longer hide the private-`:memory:` pool isolation failure mode.
- Specs lock SQLite adapter name, reject private `:memory:`, assert `ON CONFLICT` / `excluded.updated_at`, and prove pooled checkout increments.
- Adapter `unique_by` uses columns instead of the index name alone.

## Next



## Source

- `lib/onni/adapters/active_record.rb`
- `spec/dummy/config/database.yml`
- `spec/requests/sqlite_support_spec.rb`
- `README.md` SQLite section
