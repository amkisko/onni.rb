# Iterative engineering audit - stats write lifecycle

Scope: ActiveRecord hit-stat write path, request buffer flush adoption, concurrent lock pressure follow-up. Pipeline: ingress (Rack) -> evaluate/stats.record -> buffer or adapter -> DB upsert. Modes: core, performance, resource and budget (cite prior pressure ladder), trace and identification, security (no new auth), contracts (config + middleware behavior). Boundary and control: skip (library, no actuators). Product-surface: skip (no new person UI). Privacy: skip (no new personal identifiers). Learned-systems / lineage: skip.

## Participants

Andrei Makarov (@amkisko)

## Decisions

Findings (pre-fix), ranked:

1. High (performance / adoption): `stats_buffer` exists and measured ~25x wall win at W=8, but hosts must remember `reset_request!`. Initializer leaves buffer commented; no Rack middleware. Missed flush loses hits or falls back to per-evaluation upsert lock pressure.
2. Medium (hot path / DB): `record_stats_batch` loops one upsert per feature and per enabled/disabled side (up to 2N statements) inside a transaction. Multi-flag request flush still multiplies row locks and round-trips. Single `upsert_all` with `excluded.*` increments is the smallest fix.
3. Medium (coverage): no request-lifecycle or batch SQL-shape specs; buffer specs only cover Memory adapter flush.
4. Low (contract): no `request_preload` config; README tells hosts to call `preload!` manually next to buffer.
5. Inference (resource): process-wide async rollup not justified until buffer+sample saturates; prior pressure episode stop criteria hold.
6. Trace: stats middleware must not mint identifiers; only flush fiber-local counters. Confirmed no new marks planned.

Fix order this pass: middleware + `request_preload` config; ActiveRecord batch upsert; specs; initializer/README/RBS; re-audit.

## Effects

Findings fixed:

- High (adoption): `Onni::Middleware::RequestLifecycle` installed by the engine; always `reset_request!` after the request; flushes `stats_buffer` when enabled. Specs cover flush, raise path, and preload on/off.
- Medium (hot path): `record_stats_batch` uses one `upsert_all` with `excluded.enabled_hits` / `excluded.disabled_hits`. Specs cover multi-feature write, second-batch increment, empty skip, and SQL shape.
- Medium (coverage): middleware + ActiveRecord batch specs added; engine asserts middleware in the stack.
- Low (contract): `config.request_preload`; initializer template and README updated; RBS extended.
- Organization: stat write helpers moved to `adapters/active_record/stat_writes.rb` (adapter file under 150 LOC).

Validation (observed):

- Focused: `bundle exec rspec spec/onni/middleware/request_lifecycle_spec.rb spec/onni/adapters/active_record_stats_batch_spec.rb spec/onni/engine_spec.rb spec/onni/stats_buffer_spec.rb spec/requests/sqlite_support_spec.rb spec/requests/active_record_adapter_spec.rb` -> 27 examples, 0 failures.
- Full: `bundle exec rspec` -> 151 examples, 0 failures.
- `bundle exec rbs validate` -> exit 0.
- `ruby usr/bin/check_loc.rb` -> exit 0 (new files under 150 LOC).

Re-audit pass: no remaining high-confidence first-party candidates on this path above the prior pressure stop (async rollup still YAGNI). Trace: middleware emits no new identifiers. Security: no new trust boundary. Resource: batch reduces round-trips (inference until a multi-flag ladder); single-hot-key concurrent path unchanged and still owned by `stats_buffer`.

## Next

- Leave async rollup and PostgreSQL wait-event sibling deferred.
- Hosts still opt into `stats_buffer = true` (middleware alone does not coalesce).

## Source

- `docs/issues/20261113051356_pressure-stats-write-locks.md`
- `lib/onni/adapters/active_record.rb`, `lib/onni/stats/buffer.rb`, `lib/onni/engine.rb`
- `benchmarks/output/20261113051612_stats_write.json`
