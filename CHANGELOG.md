# CHANGELOG

## Unreleased

- Document concurrent hit-stat write lock pressure and host levers (`stats_buffer`, sample, ignore)
- Add ActiveRecord stats-write pressure probe (`benchmarks/stats_write.rb`) and L1 direct ceilings
- Rails `RequestLifecycle` middleware always `reset_request!`; optional `request_preload`
- ActiveRecord `record_stats_batch` uses one `upsert_all` for multi-flag flush (both hit columns)

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
