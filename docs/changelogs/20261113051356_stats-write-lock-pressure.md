# Stats write lock pressure binding and host guidance

Intent: publish measured concurrent upsert pressure on the hit-stats table and point hosts at buffer/sample before more writers.

## Participants

Andrei Makarov (@amkisko)

## Decisions

Add ActiveRecord stats-write pressure probe and binding. Document that lock pressure starts at the second concurrent writer on the same hour bucket, and that `stats_buffer` is the first lever for high request volume.

## Effects

- `benchmarks/stats_write.rb` ladder/matrix/gate/observe for direct, buffer, and sample modes
- `benchmarks/stats_write_binding.md` and `benchmarks/stats_write_ceilings.json` (direct L1 W=8)
- README concurrent hit-write section with measured walls and host order of levers
- Makefile targets `bench-stats-calibrate`, `bench-stats-ladder`, `bench-stats-gate`
- Live-work: `docs/issues/20261113051356_pressure-stats-write-locks.md`
- Follow-up audit pass: `Onni::Middleware::RequestLifecycle`, `request_preload`, batch `upsert_all` (`docs/reviews/20261113053059_iterative-engineering-audit-stats-lifecycle.md`)

## Next

- PostgreSQL wait-event sibling when a local probe DB is available

## Source

- `docs/issues/20261113051356_pressure-stats-write-locks.md`
- `benchmarks/output/20261113051612_stats_write.json`
