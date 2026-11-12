# Admin inspect without hits; migrate variants gates

## Participants

Andrei Makarov (@amkisko)

## Decisions

Stop ActiveAdmin Features index from recording experiment hit stats. Allow inspect-only evaluation via `record_stats: false`. Import Onni-native `variants` gates through `Onni.migrate!`.

## Effects

- `enabled?` / `disabled?` / `variant` accept `record_stats:` (default true).
- ActiveAdmin index uses inspect-only checks.
- Migrator imports `variants` gate rows.
- Flag memoizes definition and gates for a single request object.
- `bundle exec rspec`: 46 examples, 0 failures.

## Next

- Include in 0.1.0 release notes when tagging.

## Source

- `docs/reviews/20261112120000_iterative-engineering-audit-pass-3.md`
- `CHANGELOG.md`
