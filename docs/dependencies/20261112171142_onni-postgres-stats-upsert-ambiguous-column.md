# Onni PostgreSQL stats upsert ambiguous column

## Participants

Andrei Makarov.

## Dependency

onni (~> 0.1.0), lockfile onni (0.1.0). Gemfile. Distribution: https://rubygems.org/gems/onni/versions/0.1.0

## Symptom

With the ActiveRecord adapter and stats enabled on PostgreSQL, `Onni.enabled?` / `Onni.variant` log `Onni stats failed: ActiveRecord::StatementInvalid: PG::AmbiguousColumn` for `disabled_hits` / `enabled_hits` during hit-bucket upsert. Flag evaluation still returns; only the stats write fails (rescued and warned).

## Evidence

1. Observed while booting an app after adopting onni 0.1.0 and calling `Onni.enabled?(:new_checkout)` against a development PostgreSQL database.
2. Upstream `Onni::Adapters::ActiveRecord#upsert_stat_row` (0.1.0) built `on_duplicate: Arel.sql("#{column} = #{column} + #{weight}, updated_at = excluded.updated_at")`.
3. Reproduced on PostgreSQL 16 with the same SET shape: `ERROR: column reference "enabled_hits" is ambiguous` on the RHS when `excluded.updated_at` is also referenced. Table-qualified RHS (`enabled_hits = onni_feature_stat_buckets.enabled_hits + 1`) succeeds. PostgreSQL docs: SET/WHERE may see the target table and `excluded`; bare names are ambiguous. SET assignment targets must stay unqualified.

## Suggested fix

Upgrade to onni 0.1.1 or newer (RHS table-qualified). Workaround on 0.1.0: keep using Onni for gates; accept missing hit buckets, or set `config.stats_enabled = false` if the warn noise matters more than stats. Do not patch the installed gem in the app.

## Effects

- Fixed in this repository for 0.1.1: `upsert_stat_row` uses `#{column} = #{table}.#{column} + #{weight}`.
- SQLite upsert SQL-shape spec requires the qualified RHS form.

## Next

- Deliver onni 0.1.1 to RubyGems; bump consumer Gemfile.lock after publish.

## Source

- https://rubygems.org/gems/onni/versions/0.1.0
- https://github.com/amkisko/onni.rb
- `lib/onni/adapters/active_record.rb` (`upsert_stat_row`)
- https://www.postgresql.org/docs/current/sql-insert.html (ON CONFLICT DO UPDATE / excluded)
