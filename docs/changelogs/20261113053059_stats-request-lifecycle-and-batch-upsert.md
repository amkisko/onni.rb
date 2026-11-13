# Stats request lifecycle middleware and batch upsert

Intent: close the stats_buffer adoption gap and cut multi-flag flush round-trips after the lock-pressure audit.

## Participants

Andrei Makarov (@amkisko)

## Decisions

Ship Rack `RequestLifecycle` from the Rails engine so `reset_request!` always runs. Add `request_preload`. Replace ActiveRecord `record_stats_batch` loop with one `upsert_all`.

## Effects

- `lib/onni/middleware/request_lifecycle.rb` + engine initializer `onni.request_middleware`
- `config.request_preload`
- `lib/onni/adapters/active_record/stat_writes.rb` (`upsert_all` for batch; single-row upsert unchanged)
- Specs: middleware, batch SQL shape, engine middleware presence
- Initializer template and README updated

## Next

- Optional: observe buffer mode under stats_write ladder after hosts enable `stats_buffer` by default in their apps

## Source

- `docs/reviews/20261113053059_iterative-engineering-audit-stats-lifecycle.md`
- `docs/issues/20261113051356_pressure-stats-write-locks.md`
