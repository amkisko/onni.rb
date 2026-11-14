# Delivery, signals and catalogue implementation

## Participants

Andrei Makarov (@amkisko).

## Decisions

Implement RFC-0008 through RFC-0011 from the delivery plan. Keep optional later
weighted selection and per-experiment power out of scope. Use existing gates
for bounded signal levels and policies. Specs precede each executable slice.
Run iterative engineering audit and calibrated pressure benchmarking, with at
least ten optimize/prove iterations before accepting a pressure episode.
Memory probe is process_lifetime; network is not_in_scope for local fixtures.

Pressure decision after iteration 10: permit increases only to the four stage
latency ceilings, using max observed over the ten iterations and final five
samples times 1.15. Earlier 15-percent headroom on one three-sample baseline
was smaller than observed stage variation. Preserve every failed series name in
delivery_iterations.json; keep raw prove samples under benchmarks/output/. This
is an explicit allow-raise decision, not a claim of latency improvement. Tighten
wall/CPU to final five-sample max times 1.15, retained fixture bytes to 90, and
uncompressed shipped source to 148000 bytes. Keep the initial RSS ceiling.
Stop optimization after ten cycles: no remaining high-confidence first-party
candidate justifies more changes for this bounded fixture. Recheck final gates.

## Effects

Implemented RFC-0008 through RFC-0011, with tests exposing missing contracts
before implementation. Added Delivery routing/fallback, integer signals with
atomic threshold park, committed mutation events, transaction-bound preloads,
expiration review, catalogue export/tasks and ActiveAdmin controls.

Completed 12 iterative audit/pressure cycles. The final memory and durable
resource gates pass; the independent 8-process probe retained all 800 updates
with one park event in each of three samples. The implementation review records
13 resolved findings, raw evidence, exact commands and remaining scope limits.
The final full suite passed 494 examples and reached 95.73 percent line coverage.
RuboCop, RBS, locale parity, LOC gate and local gem build passed.

## Next

Cut recorded as 3.0.0; deliver with `make release`. Host-specific rollout
checks remain maintainer actions after publish.

## Source

- [Plan](../plans/20261114103806_exception-rate-park-and-error-stats.md)
- [RFC-0008](../../rfcs/0008-expiration-hygiene.md)
- [RFC-0009](../../rfcs/0009-integer-signals.md)
- [RFC-0010](../../rfcs/0010-delivery-experiments.md)
- [RFC-0011](../../rfcs/0011-catalogue-export.md)

- [Implementation review](../reviews/20261114123346_delivery-implementation-audit.md)
- [Pressure binding](../../benchmarks/delivery_binding.md)
- [Engineering changelog](../changelogs/20261114122926_delivery-signals-and-catalogue.md)
