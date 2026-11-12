# Engineering audit

## Participants

Andrei Makarov (@amkisko)

## Decisions

The review covered the Ruby runtime (`lib/onni/**`), memory and ActiveRecord adapters, optional ActiveAdmin dashboard, prior-library migrator, generators, specs, CI packaging paths, Pray/AGENTS skills, and the pressure load harness. Pipeline focus: YAML registry ingress -> Store evaluate -> adapter gates -> optional host cache -> stats/egress. Boundary mode treated ActiveAdmin and host `authorize`/cache as operator surfaces. Learned-system and physical-actuator checks do not apply.

Findings fixed in this pass:

- High (product contract): `expires_at` was display-only while gates still evaluated. `Store#evaluate` now fails closed when the deadline is past; `Registry` parses `expires_at_time` once at load. README documents the contract. Spec added.
- Medium (hot path): `Conditions` resolved group names via linear `Group.names` scan. `Group.known?` is O(1); conditions use it.
- Medium (isolation / alloc): Memory `gates_for` returned a shallow array `dup` that still shared gate hashes. Empty keys now return a frozen empty array; non-empty keys map `dup` per gate hash.
- Low (cache key churn): `Store` cache keys use a frozen `CACHE_KEY_PREFIX` constant.
- Low (conditions path): `Conditions.met?` accepts an already-loaded definition so evaluate avoids a second registry lookup when conditions run.

Open / deferred (no high residual after pass):

- Medium (concurrency): ActiveRecord `record_stat` uses `find_or_create_by!` then `update_all`. Concurrent first-hit races can raise; hosts should treat stats as best-effort (already rescued in `Stats.record`). Prefer a single upsert when a host DB dialect is required.
- Low (coverage): ActiveAdmin dashboard and AR adapter paths lack integration specs in this tree; memory Store coverage is the primary suite (13 examples).
- Skip: learned systems, physical control, network egress (memory adapter pressure probe is `not_in_scope` for network).

Resource and budget: pressure binding at `benchmarks/binding.md`; L1 gate green after cooker episode (see `docs/issues/20261112084200_pressure-cooker-episode.md`). Trace and identification: actor ids and feature keys appear in adapter gates and optional stats buckets by design; no new identifiers added.

Stack selection: Ruby gem + optional Rails/ActiveAdmin engine, YAML registry, pluggable memory/AR adapters - matches preferred-stack and peer gems. RFCs and docs-conventions prayers are composed into `AGENTS.md`; skills tree includes `engineering-audit`, `pressure-benchmarking`, `preferred-stack`, `rfc-process`.

## Effects

- `bundle exec rspec`: 13 examples, 0 failures.
- Calibrate + L1 gate (`SAMPLES=5`, `N=10_000`): PASS under `benchmarks/ceilings.json` (RSS not gated).
- Prayfile wires docs-conventions, preferred-stack, rfc-process, engineering-audit, pressure-benchmarking.

## Next

- Add AR adapter / admin request specs when a host appraisal matrix is exercised in CI.
- Consider dialect-specific stats upsert if production hosts enable `stats_enabled` under write contention.
- Keep ceilings tighten-only on slower CI hosts; do not reintroduce RSS gates under `process_lifetime`.

## Source

- `lib/onni/store.rb`
- `lib/onni/registry.rb`
- `lib/onni/conditions.rb`
- `lib/onni/group.rb`
- `lib/onni/adapters/memory.rb`
- `lib/onni/adapters/active_record.rb`
- `benchmarks/binding.md`
- `docs/issues/20261112084200_pressure-cooker-episode.md`
- `Prayfile`
