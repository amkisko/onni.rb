# Iterative engineering audit pass 3 - admin stats, migrator variants

## Participants

Andrei Makarov (@amkisko)

## Decisions

Pipeline re-check after pass 2: registry -> Store evaluate -> adapter -> cache -> stats. Product-surface mode on ActiveAdmin Features index. Security mode: no new trust boundary; dashboard inspect must not invent experiment traffic. Durable-cache unchanged. Resource and budget: Flag memoizes `definition` and `gates` per instance to avoid repeat adapter/registry digs on the show page.

In scope: admin hit pollution, `record_stats:` contract, variants gate import, Flag unit coverage, RBS for Store/Stats/Migrator. Out of scope: Redis, expression gates, audit log, generator smoke (deferred).

## Effects

Findings fixed:

- High (product / observability): Features index called `flag.enabled?`, which recorded a hit per flag per page view (`demo` and `search_v2` buckets appeared with no app traffic). Added `record_stats:` on `Onni.enabled?` / `disabled?` / `variant`, `Flag#enabled?`, and `Store`; admin index uses `record_stats: false`. Specs cover skip path and index render with zero `StatBucket` rows.
- Medium (contract): migrator skipped `variants` gates. `SUPPORTED_GATE_KEYS` now includes `variants`. README and importer comment updated. Spec imports a JSON variants gate.
- Low (coverage / types): `Flag` specs for YAML vs gate variant precedence; `sig/onni.rbs` extended for Store, Stats, Migrator, and `record_stats:`.
- Low (isolation): migrator and Flag specs restore `stats_enabled` after mutation.
- Low (admin path): `Flag#definition` and `Flag#gates` memoized per instance.

Validation: `bundle exec rspec` -> 46 examples, 0 failures (multiple random seeds).

## Next

- Done: generator smoke spec for `onni:install`.
- Done: pressure L1 re-run covered in later all-features / preload episodes.
- Non-goals remain Redis adapters, expression gates, authorization misuse.

## Source

- `lib/onni.rb`, `lib/onni/store.rb`, `lib/onni/flag.rb`
- `app/admin/features.rb`
- `lib/onni/migrator/importer.rb`
- `sig/onni.rbs`
- `spec/requests/admin_features_spec.rb`
- `spec/onni/store_spec.rb`, `spec/onni/flag_spec.rb`, `spec/onni/migrator_importer_spec.rb`
- `docs/reviews/20261112114500_iterative-engineering-audit.md`
