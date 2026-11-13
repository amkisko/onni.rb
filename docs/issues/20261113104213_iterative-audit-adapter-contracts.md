# Iterative audit of adapter contracts

## Participants

Andrei Makarov (@amkisko), confirmed in this session.

## Decisions

Audit, reproduce with executable specs, repair, benchmark, then inspect the next
boundary. Every retained fix requires a before/after benchmark. Do not change
dependencies or published API shapes. Baseline: clean checkout at session start.

Pipeline: import or Ruby evaluation -> typed registry -> adapter gates -> request
and shared-cache copies -> evaluation -> sampling -> buffer -> hourly counters
-> history query and admin chart. Inspect the admin and release boundaries too.

Five alternating isolated before/after samples use the same probe and workload.
Measure process CPU, wall time, allocations, native process-lifetime peak RSS,
source bytes, and serialized fixture row bytes. CPU seconds are the energy
proxy. No network is involved in these fixtures. Use a 3% timing noise floor.

Before measuring fixes, set diagnostic budgets: import CPU ratio <= 1.25;
small fallback flush CPU ratio <= 1.25; large fallback flush CPU ratio <= 3.0;
history query CPU ratio <= 1.5. Each fix also requires its correctness oracle.
These are episode budgets, not changes to the published hot-path ceilings.
Run the existing absolute hot-path gate after all repairs.

## Effects

Completed four audit/repair rounds. Five baseline defects are repaired, and
re-audit rejected an intermediate import implementation that required Hash
methods from indexed source rows. Each runtime repair has before/after samples.
The final absolute gate passes unchanged limits. The import error-fixture
diagnostic exceeds its CPU ratio budget; this is retained as a measured
correctness cost, not hidden by changing the budget.

The first measurement against the live worktree rejected a source change during
unrelated version/release work. Accepted measurements use frozen source copies.
Storage diagnostics initially counted a summary; final evidence counts complete
fixture rows. These changes supersede those earlier measurements.

Findings, reproduction commands, outcomes, scope limits, and accepted raw samples
live in the linked review and evidence bundle.

## Next

No repair remains open in the three inspected adapter paths. A separate episode
is needed for deployment-specific cache consistency or sustained multi-process
storage pressure. The referenced `spec/README.md` is absent; sibling specs guided
the tests in this episode.

## Source

- [Import regressions](../../spec/onni/migrator_importer_spec.rb)
- [Audit probe](../../benchmarks/audit_probe.rb)
- [Benchmark runner](../../benchmarks/pressure_runner.rb)
- [Completed review](../reviews/20261113104754_iterative-audit-adapter-contracts.md)
- [Measured evidence](../../benchmarks/engineering_audit_results.json)
