# CHANGELOG

## Unreleased

## 2.0.0 (2026-11-13)

- Compose audience groups, actor lists, excludes, and a percentage on one flag
- Preserve rollout and experiment settings across `park!` and `ready!`; use `clear!` to reset
- Replace ordinary YAML audience types with filters; require an explicit experiment audience (breaking)
- Count pending and parked evaluations; collect all calls by default in new installations
- Control statistics at each call site, in feature defaults, or through runtime settings
- Preserve flags and counters when changing ordinary application settings
- Define documented, expiring flags at runtime with `Onni.define!`; prefer the shared YAML catalogue
- Fix `Onni::RSpec.install!` so the before hook calls `Onni::RSpec.reset!` under RSpec `instance_exec`

## 1.0.1 (2026-11-13)

- Register ActiveAdmin Features pages before routes draw so production boot keeps `admin_features_path`
- Add `Onni::Migrator::ActiveRecordTables` and a generic prior-library cutover checklist in the README
- Add `require "onni/rspec"` host helper for memory adapter reset
- Install generator: safer stats defaults (`stats_buffer`, sample `0.1`) and ActiveAdmin/Tailwind reminders

## 1.0.0 (2026-11-13)

- Use the Ruby standard library for the core with zero runtime gem dependencies
- Load ActiveSupport, ActiveRecord, Rails, and ActiveAdmin integrations explicitly
- Configure retention in elapsed seconds and select persistence in the host application
- Default YAML flags to group; allow declarations with only description and expiry
- Separate ready/pending/parked power from `visible?` evaluation with typed YAML defaults
- Replace power, audience, and dial APIs with ready/park, visible/drop, and level; remove old names
- Restore pending on `clear!`; retain ready power for soft zero levels
- Count ready evaluations with `shown_count` / `skip_count`; provide reversible upgrades for both older schemas
- Use Ready/Park commands and All/Ready/Pending/Parked scopes in ActiveAdmin
- Name the evaluation chart `VisibilityChart`; use Flags throughout dashboard navigation
- Reduce evaluation CPU and allocations; load admin flag gates in one query
- Preserve full buffered counts above the per-evaluation sample-weight limit
- Keep request results and application errors intact when stats flushing fails
- Prevent delayed cache fills from restoring stale gates after a local mutation
- Isolate stored memory gates from caller mutations and aborted updates
- Document concurrent hit-stat write lock pressure and host levers (`stats_buffer`, sample, ignore)
- Rails `RequestLifecycle` middleware always `reset_request!`; optional `request_preload`
- ActiveRecord multi-flag stats flush uses one upsert for both count columns

## 0.1.3 (2026-11-12)

- ActiveAdmin Features index is Flags: search, expiry filters, pagination, All/Enabled/Disabled scope tabs with counts
- Flags filters sit in the ActiveAdmin sidebar (`filters-form`)
- Stats storage is a separate page (`/admin/features/stats`)
- Optional `/admin/features/:key` show path via `Onni::ActiveAdminRoutes.draw`
- Feature show uses ActiveAdmin layout wrappers and paginated table chrome
- Colored Enable (orange) and Disable (red) actions on the Flags index

## 0.1.2 (2026-11-12)

- ActiveAdmin Features index: one Enable or Disable action per flag, relative expiry with full date hint, compact hit metrics, no explainer panels
- ActiveAdmin feature show: denser metrics, shorter hit copy, relative expiry

## 0.1.1 (2026-11-12)

- Fix PostgreSQL hit stats upsert so `enabled_hits` / `disabled_hits` record again (ambiguous column with `excluded`)

## 0.1.0 (2026-11-12)

- Add feature evaluation charts with 24-hour, 7-day, and 30-day history, enabled share, expandable counts, and replaceable views
- Initial gem: YAML registry, runtime gates, groups, percentage rollout, A/B variants, hit stats
- Solid core usable in any Ruby app (memory adapter by default)
- Optional ActiveRecord adapter and Rails engine
- First-class pluggable ActiveAdmin dashboard support
- Pluggable migrator (`Onni.migrate!`) for importing gates from another feature-flag library
- Fail closed on past or unparseable `expires_at` for `enabled?` / `variant`
- Allow `register_group` from the boot empty registry (no prior `clear!` required)
- Record ActiveRecord hit stats with a unique-index upsert (avoids first-hit create races)
- Add `record_stats:` on `enabled?` / `variant` / `disabled?`; ActiveAdmin index inspects without recording hits
- Import `variants` gates via `Onni.migrate!`
- Add `Onni.purge_stats!` / `Onni::Stats::Purge` with batched retention cleanup
- Add `rails g onni:stats_cleanup` (job + `period_start` index) and README growth guidance
- Default `config.stats_retention = 90.days`
- Stats sampling: clamp `stats_sample_rate` to 0.0..1.0, skip Random at 1.0, optional `stats_sampler` / `stats_ignore`, scale kept samples by ~1/rate (`stats_scale_sampled_hits`)
- Add `ActiveSupport::Notifications` (`*.onni`) for stats record/purge and enable/disable
- Add `Onni.stats_overview` and ActiveAdmin Hit storage panel (retention / cleanup signals)
- Add configurable `concurrency` (`:mutex` default for threads/fibers, `:none` to skip locks)
- Document that Onni is for experiments and stats - not authorization
- Pressure binding and L1 load ceilings for the memory all-features evaluate path (boolean, actor, percentage, group, variant, conditions, stats)
- Add request preload (`Onni.preload!` / `gates_for_many`) and optional `stats_buffer` with `flush_stats!` / `reset_request!`
- Lean `Store.variant` reuses one gates fetch (no second adapter read / Flag allocate)
- Instrument group/percentage/variants mutations; ActiveAdmin show shows hit sample rate; `onni:install` smoke spec; expanded RBS; upsert dialect note
- First-class SQLite support: shared file DB in dummy, column `unique_by` upsert conflict target, pool/ON CONFLICT specs, host timeout/WAL notes
- Rails dummy + request specs for ActiveRecord adapter and ActiveAdmin Features page
- Unit specs for Group, Registry, Actor, Conditions, and Flag
