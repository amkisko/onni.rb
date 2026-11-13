# Onni::RSpec.install! engineering audit

## Participants

Andrei

## Decisions

Audit scoped to `lib/onni/rspec.rb` and its helper spec. Pipeline: host `install!` ingress -> RSpec before hook -> `reset!` (adapter + request store) -> example egress. Boundary/control skipped (no physical actuators). Privacy skipped (no person identifiers). Security skipped (test helper only; no auth or attacker path). Observability skipped (no service process). Product surface skipped (no person-facing UI). Learned-systems and lineage skipped. Resource and budget: reset is O(1) process-local; no new bench this pass. Trace and identification: helper clears request store only; no new emissions. Contracts: `install!` / `reset!` remain the public helper surface; behavior fix only.

## Effects

Findings this pass:

1. Critical (contracts / app logic): unqualified `reset!` inside `before` fails under RSpec `instance_exec`. Evidence: red `instance_exec` example before fix; green after `Onni::RSpec.reset!`. Confidence high. Evidence kind observed.
2. High (futile coverage): previous install example used `block.call` plus `receive(:reset!)`, so it never saw the binding bug. Replaced with `instance_exec` behavioral assert. Confidence high. Evidence kind observed.
3. Low (organization): only one RSpec hook registration in `lib/`; no sibling unqualified hooks found. Confidence high. Evidence kind observed.
4. Low (resource): `reset!` still sets memory adapter and clears request/adapter caches once per example; unchanged cost class. Confidence medium. Evidence kind inference (no RSS/CPU sample this pass). Check that would measure: host suite wall time with/without `install!` on a fixed seed.

Modes run: core dimensions, pipeline, contracts, resource and budget (qualitative), trace and identification (no new id). Modes skipped named above.

## Next

- Patch release containing the qualified hook.
- Optional: one host-suite smoke that requires `onni/rspec` and calls `install!` against real `RSpec.configuration` in an isolated process.

## Source

- `lib/onni/rspec.rb`
- `spec/onni/rspec_helper_spec.rb`
- `docs/dependencies/20261113171641_onni-rspec-install-unqualified-reset.md`
