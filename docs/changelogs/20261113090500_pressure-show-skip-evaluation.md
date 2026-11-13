# Show/skip evaluation pressure episode

## Participants

Andrei Makarov (@amkisko), the operator named in the implementation plan.

## Decisions

Optimize the show/skip implementation with calibrated, individual change/prove
cycles. Keep evaluation and mutation semantics, and retain measured correctness
repairs even when they have an explicit write or cache cost. Use the existing
Ruby runtime and dependencies.

## Effects

Complete fifteen measured cycles: one pilot and fourteen counted improvements.
The final five-sample comparison reduces median CPU 23.9% and allocations 44.5%
for the seven-path memory evaluation walk. Promote the unchanged tighter limits
after an independent passing gate. RSS stays at a similar level; compressed gem
bytes grow by 1024. Gate mutation CPU grows 7.0% against the pre-snapshot build.

Remove repeated read-path work and reuse immutable memory gate snapshots. Keep
public gate rows independent from caller values and aborted updates. Bulk-load
admin gate reads, preserve aggregate weighted counts, protect request outcomes
from telemetry failures, and prevent stale cache fills after local mutations.

The full 202-example suite, lint/type/locale checks, stock load gate, and SQLite
write gate pass. The audit and evidence preserve failed intermediate outcomes,
measurement limitations, and exact commands.

## Next

Review the implementation and measured costs before release. Cross-process cache
consistency and sustained load remain separate work with explicit requirements.

## Source

- [Engineering audit](../reviews/20261113090500_pressure-engineering-audit.md)
- [Live work](../issues/20261113071037_pressure-show-skip-evaluation.md)
- [Evidence](../../benchmarks/show_skip_pressure_results.json)
- [Product release notes](../../CHANGELOG.md)
