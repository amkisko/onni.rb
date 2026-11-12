# Audit fixes - group boot, stats upsert, expiry fail-closed

## Participants

Andrei Makarov (@amkisko)

## Decisions

Ship three contract/operability fixes found in the iterative engineering audit before public 0.1.0: writable Group registry at boot, race-safe ActiveRecord hit stats, fail-closed unparseable `expires_at`. Keep Redis, expression gates, and audit logs out of this cut.

## Effects

- `Group.register` works without a prior `clear!`.
- ActiveRecord `record_stat` uses unique-index upsert with hit increment on conflict.
- Unparseable `expires_at` disables evaluation (`enabled?` / `variant`).
- Spec suite isolation for configuration; new unit coverage for Group, Registry, Actor, Conditions.
- `bundle exec rspec`: 40 examples, 0 failures.

## Next

- Fold into the 0.1.0 release notes when cutting the tag.
- Re-run pressure L1 if Store hot path changes again.

## Source

- `docs/reviews/20261112114500_iterative-engineering-audit.md`
- `CHANGELOG.md`
