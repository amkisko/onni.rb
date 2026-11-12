# onni

[![Test Status](https://github.com/amkisko/onni.rb/actions/workflows/test.yml/badge.svg)](https://github.com/amkisko/onni.rb/actions/workflows/test.yml)

Feature flags, gradual rollout, A/B variants, audience targeting groups, and hit stats for any Ruby app. Optional ActiveRecord persistence and first-class pluggable ActiveAdmin support.

## What Onni is for

Use Onni to:

- turn product experiments and incomplete surfaces on or off
- roll a change out to a percentage of actors or a named audience group
- assign A/B (or multi-arm) variants
- collect enabled/disabled hit stats for analysis

## What Onni is not for

**Do not use Onni as an authorization or access-control system.**

`Onni.enabled?` answers “is this flag on for this actor for experiment / rollout purposes?”, not “may this principal perform this privileged action?”. Keep authentication and authorization in your policy layer (for example Pundit, CanCanCan, or host middleware). A flag may *gate whether a UI is offered*; it must not be the only check that protects a write, read of private data, or admin capability.

YAML `conditions` and registered groups are targeting helpers for rollouts. They are not a substitute for object-, function-, or tenant-level authorization.

## Requirements

- Ruby 3.4+
- ActiveSupport 7.2.3.2+
- Optional: Rails 7.2.3.2+ (engine, ActiveRecord adapter)
- Optional: ActiveAdmin 4.0.0.beta23+ (admin dashboard)

## Install

From RubyGems after a release:

```ruby
# Gemfile
gem "onni"
```

From git:

```ruby
# Gemfile
gem "onni", github: "amkisko/onni.rb"
```

Rails + ActiveRecord:

```sh
bin/rails generate onni:install
bin/rails db:migrate
```

ActiveAdmin dashboard loads automatically when ActiveAdmin is present. You can also require it explicitly:

```ruby
require "onni/active_admin"
```

## YAML registry

Every flag must be listed in `config/features.yml`:

```yaml
new_checkout:
  expires_at: "2027-06-01"
  description: "Checkout redesign experiment"
  variants:
    control: 50
    treatment: 50
```

Unknown names fail closed: `enabled?` returns false; `enable` / `disable` raise `KeyError`.
Past or unparseable `expires_at` values fail closed on `enabled?` / `variant`. The ActiveAdmin UI still shows the expiry date.

Optional YAML `conditions` (checked after a gate matches, when an actor is present). These narrow a rollout audience; they are not authorization:

```yaml
search_v2:
  expires_at: "2027-06-01"
  description: "New search UI for beta testers"
  conditions:
    - beta_tester?
    - beta_testers   # registered Onni group name
```

## Runtime API

```ruby
Onni.enabled?(:new_checkout, user)
Onni.enabled?(:new_checkout, record_stats: false) # inspect without recording a hit
Onni.enable(:new_checkout)
Onni.enable(:new_checkout, user)
Onni.disable(:new_checkout)
Onni.enable_group(:search_v2, :beta_testers)
Onni.enable_percentage_of_actors(:homepage_banner, 25)
Onni.set_variants(:new_checkout, {control: 50, treatment: 50})
Onni.variant(:new_checkout, user) # => :control / :treatment
Onni.register_group(:beta_testers) { |actor, _| actor.beta_tester? }
```

Gates: `boolean`, `actors`, `groups`, `percentage_of_actors`, `variants`.

`Onni.exist?(name)` is adapter-backed (gates/feature rows). `Onni::Flag#exist?` is YAML-registry-backed.

## Stats

Each `enabled?` / `variant` evaluation can record enabled/disabled hits into hourly buckets. Pass `record_stats: false` for inspect-only checks (the ActiveAdmin index does this). View samples on `/admin/features` for analysis. Stats are operational telemetry for experiments, not an audit log for authorization decisions.

Rows are created only when a hit is recorded for that flag and hour. Quiet hours leave no row.

### Instrumentation

Onni publishes `ActiveSupport::Notifications` events:

- `stats.record.onni` — a kept hit write (`:name`, `:enabled`, `:weight`)
- `stats.purge.onni` — purge batch/drain result (`:deleted`, `:processed_count`, `:continued`)
- `feature_operation.onni` — mutations (`:feature_name`, `:operation`, `:result`; optional `:actor_id`, `:group_name`, `:percentage`). Operations: `enable`, `disable`, `enable_group`, `disable_group`, `enable_percentage_of_actors`, `set_variants`

```ruby
ActiveSupport::Notifications.subscribe(/\.onni$/) do |event|
  Rails.logger.info([event.name, event.payload].inspect)
end
```

`Onni.stats_overview` (also on the ActiveAdmin Features page) reports bucket count, oldest hour, retention, and whether cleanup is overdue.

### Sampling

- `stats_sample_rate` is a float in `0.0..1.0` (clamped on assign). `1.0` records everything and skips `Random`.
- `stats_sampler` is an optional callable `|ctx|` with `ctx[:name]` and `ctx[:enabled]`; return a rate, `true`/`false`, or `nil` to fall back to `stats_sample_rate`.
- `stats_ignore` lists feature keys that never write buckets.
- `stats_scale_sampled_hits` (default `true`): when a sample is kept at rate `r`, the bucket increments by about `1/r` so totals estimate full traffic. Set `false` to store raw kept-sample counts only.

```ruby
Onni.configure do |config|
  config.stats_sample_rate = 0.1
  config.stats_ignore = %w[noisy_probe]
  config.stats_sampler = ->(ctx) { ctx[:name] == "checkout_v2" ? 1.0 : nil }
end
```

### Request preload and stats buffer

Hosts that evaluate many flags per request can cut adapter reads and coalesce hit writes:

```ruby
# Once per request (middleware / around_action), after configure:
Onni.preload!                 # all YAML keys, or Onni.preload!(:new_checkout, :search_v2)
Onni.configuration.stats_buffer = true

# ... enabled? / variant calls use the fiber-local gate map ...

Onni.reset_request!           # flushes buffered stats (when enabled) and clears preload
# or: Onni.flush_stats!
```

`gates_for_many` loads ActiveRecord gates in one `WHERE feature_key IN (...)` query. Memory adapter uses one lock section. Preload is fiber-local (safe with threads and fibers on Ruby 3.4+).

### Stats growth and cleanup

Default retention is `config.stats_retention = 90.days`. Install a batched cleanup job and a `period_start` index:

```sh
bin/rails generate onni:stats_cleanup
bin/rails db:migrate
```

Schedule daily (host job backend or cron):

```ruby
OnniPurgeStatsJob.perform_later
```

One-shot drain without a queue (pages until done in-process):

```ruby
Onni.purge_stats!(older_than: 90.days.ago)
# or: Onni::Stats.purge!(batch_size: 1_000)
```

Rough size: rows grow with `(flags that see traffic) x (hours with at least one recorded hit)`. Sampling (`stats_sample_rate`) and shorter retention shrink that. Prefer `stats_ignore` or a low `stats_sampler` rate for very hot flags before lengthening retention alone.

When the table is already large (about **>1GB** or **>10M rows**):

1. Schedule or run purge immediately; keep `stats_retention` at a value you actually query (admin default window is 24h).
2. Lower `stats_sample_rate` if you only need trend signal, not full counts.
3. After a large delete, run your database's maintenance (`VACUUM` on SQLite, `VACUUM` / `ANALYZE` on PostgreSQL, `OPTIMIZE TABLE` where relevant).
4. **Partitioning** (for example range partitions on `period_start`) is a host DDL choice. Onni does not manage partitions; keep the unique key `(feature_key, period, period_start)` and the purge predicate (`period_start < cutoff`) efficient. Dropping old partitions can replace row-by-row delete once you partition.
5. If stats are not worth the write load, set `stats_enabled = false` and truncate or drop the table.

### SQLite

SQLite is a first-class ActiveRecord dialect for Onni (dummy app, install migration, and CI). Hit writes use `INSERT ... ON CONFLICT DO UPDATE` with `excluded.updated_at` on the unique key `(feature_key, period, period_start)`.

Host tips:

- Prefer a file database, or `file:... ?mode=memory&cache=shared`. Plain `:memory:` gives each connection-pool checkout a private empty database, so upserts fail with a missing unique index.
- Set `timeout: 5000` (milliseconds) in `database.yml` so writers wait on locks under concurrent checkouts.
- For multi-process writers, enable WAL in the host (`PRAGMA journal_mode=WAL`).
- After a large purge, run `VACUUM`.

### Other ActiveRecord dialects

PostgreSQL uses the same `excluded.*` upsert form. The conflict `SET` keeps a bare assignment target and qualifies the existing-row hit column on the RHS (`enabled_hits = onni_feature_stat_buckets.enabled_hits + ...`) so PostgreSQL does not treat the bare name as ambiguous with `excluded`. If a host dialect rejects `excluded.*`, override `Adapters::ActiveRecord#record_stat` / `#record_stats_batch` or patch the `on_duplicate` fragment for that adapter.

## ActiveAdmin dashboard access

### Hit charts

Each feature detail page includes enabled/disabled evaluation charts, totals,
enabled share, and an expandable data table. Choose Last 24 hours (hourly),
Last 7 days, or Last 30 days (daily). Times are UTC and include the current
incomplete period. The chart needs no JavaScript setup.

Counts describe evaluations, not unique users or A/B conversion results.
Sampling can produce estimates or raw sample counts. Periods without recorded
evaluations appear as zero; retention may have removed older history.

To replace the chart, add `app/views/admin/features/_chart.html.erb` in your
application. It receives an `Onni::HitChart` as the `chart` local:

```erb
<p>Enabled evaluations: <%= chart.enabled_hits %></p>
<p>Disabled evaluations: <%= chart.disabled_hits %></p>
```

Use `chart.rows` for chronological points (`period_start`, `enabled_hits`,
`disabled_hits`, all string keys), `chart.hourly?` for the interval, and
`chart.enabled_percentage` for the enabled share (`nil` without evaluations).
You can replace `app/views/admin/features/_stats.html.erb` for the entire
statistics section; it receives `chart` and `flag` locals. Onni invokes the
chart partial only when the selected window contains recorded evaluations.

### Dashboard authorization

Menu visibility and every Features page action run `admin_authorized` (instance_exec on the page controller). That callback only controls who may open the Onni dashboard in ActiveAdmin. It does not authorize application actions gated by flags. Default is allow-all — set it in the initializer:

```ruby
Onni.configure do |config|
  config.admin_authorized = -> { current_admin_user&.can_manage_experiments? }
end
```

Hosts that use Pundit/CanCanCan should also authorize ActiveAdmin page actions (`enable?`, `disable?`, `feature?`, `update_feature?`) for the Features page.

## Concurrency

Shared in-process state (memory adapter, audience groups, YAML registry cache) uses configurable locking:

```ruby
Onni.configure do |config|
  config.concurrency = :mutex # default; covers threads and fibers on Ruby 3.4+
  # config.concurrency = :none # single-threaded hosts / benchmarks
end
```

Set concurrency before the adapter is built (or call `Onni.reset_adapter!` after changing it). Do not `Fiber.yield` inside Onni critical sections.

## Test adapter

```ruby
Onni.configure { |config| config.adapter = :memory }
Onni.adapter = Onni::Adapters::Memory.new
Onni.enable(:new_checkout)
```

## Migrating from another feature-flag library

Map your previous store into a source with `#feature_keys` and `#gates`, then import once. Keep `config/features.yml` keys aligned with the names you import. Unknown YAML keys are skipped. Unsupported gate keys are counted in `skipped_gates` and not written.

```ruby
source = Onni::Migrator::Snapshot.new(
  feature_keys: %w[new_checkout search_v2],
  gates: [
    {feature_key: "new_checkout", key: "boolean", value: "true"},
    {feature_key: "search_v2", key: "percentage_of_actors", value: "25"},
    {feature_key: "search_v2", key: "groups", value: "beta_testers"},
    {feature_key: "search_v2", key: "actors", value: "User;42"}
  ]
)

Onni.migrate!(source)
# => { features:, gates:, skipped_gates: }
```

Any object that responds to `#feature_keys` and `#gates` works as a source; `Snapshot` is the built-in in-memory shape. Gate rows accept String or Symbol keys for `feature_key`, `key`, and `value`.

Imported gate keys: `boolean`, `actors`, `groups`, `percentage_of_actors`, `variants`.
Other gate keys from the prior library are skipped. YAML `variants` still win over an imported variants gate when both are present.
Replace call sites with `Onni.*` and remove the previous library when ready.

## Development

```bash
bundle install
bundle exec appraisal install
make test
```

Maintainers publish with `make release` (`usr/bin/release.rb`).
