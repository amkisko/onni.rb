# onni

[![Test Status](https://github.com/amkisko/onni.rb/actions/workflows/test.yml/badge.svg)](https://github.com/amkisko/onni.rb/actions/workflows/test.yml)

Feature flags, gradual rollout, A/B variants, audience targeting groups, and shown/skip counts for any Ruby app. Optional ActiveRecord persistence and first-class pluggable ActiveAdmin support.

## What Onni is for

Use Onni to:

- ready or park product experiments and incomplete surfaces
- roll a change out to a percentage of actors or a named audience group
- assign A/B (or multi-arm) variants
- collect shown/skip counts for analysis

## What Onni is not for

**Do not use Onni as an authorization or access-control system.**

`Onni.visible?` answers “should this actor see this feature for experiment / rollout purposes?”, not “may this principal perform this privileged action?”. Keep authentication and authorization in your policy layer (for example Pundit, CanCanCan, or host middleware). A flag may *gate whether a UI is offered*; it must not be the only check that protects a write, read of private data, or admin capability.

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

After `ActiveAdmin.routes(self)`, draw the feature detail path (`/admin/features/:key`):

```ruby
ActiveAdmin.routes(self)
Onni::ActiveAdminRoutes.draw(self)
```

`/admin/features` is the Flags index (search, filters, pagination, All/Ready/Pending/Parked scopes).
Stats storage is at `/admin/features/stats`. The older `/admin/features/feature?key=` page action remains available.

Use the host's ActiveAdmin stylesheet and JavaScript setup. Include Onni's
`app/admin` and `app/views` directories in the host's Tailwind sources alongside
ActiveAdmin's sources. The chart itself renders as SVG. For a styled local
preview, see [the contribution guide](CONTRIBUTING.md#local-checks-and-admin-preview).

Host apps that authorize ActiveAdmin page actions by name need `ready?` and `park?` rules for power commands, plus `stats?`, `feature?`, and `update_feature?` when those are checked. These are host policy methods; `Onni.visible?` remains a rollout evaluation.

## YAML registry

Every flag must be listed in `config/features.yml`:

```yaml
new_checkout:
  expires_at: "2027-01-01"
  description: "Checkout redesign experiment"
```

Omitting `type` declares a `group` flag with an empty audience. Add a registered
group with `Onni.visible_group!(:new_checkout, :beta_testers)` to make it visible
to that group's actors. `ready!` alone leaves an empty group invisible.

For an experiment with variants, declare its type explicitly instead:

```yaml
new_checkout:
  type: experiment
  expires_at: "2027-01-01"
  description: "Checkout redesign experiment"
  variants:
    control: 50
    treatment: 50
```

Unknown names fail closed: `visible?` returns false; `ready!` / `park!` raise `KeyError`.
Past or unparseable `expires_at` values fail closed on `visible?` / `variant`. The ActiveAdmin UI still shows the expiry date.

Optional YAML `conditions` (checked after a gate matches, when an actor is present). These narrow a rollout audience; they are not authorization:

```yaml
search_v2:
  type: group
  groups: [beta_testers]
  expires_at: "2027-06-01"
  description: "New search UI for beta testers"
  conditions:
    - beta_tester?
    - beta_testers   # registered Onni group name
```

## Runtime API

```ruby
Onni.visible?(:new_checkout, user)
Onni.visible?(:new_checkout, record_stats: false) # inspect without recording
Onni.ready!(:new_checkout) # power on with YAML type and defaults
Onni.park!(:new_checkout) # hard-off; clear overrides; no evaluation stats
Onni.ready?(:new_checkout) # runtime power, independent of audience matching
Onni.pending?(:new_checkout) # no power decision since creation or clear!
Onni.parked?(:new_checkout) # explicit hard-off without evaluating an actor
Onni.clear!(:new_checkout) # remove overrides and restore pending
Onni.visible_group!(:search_v2, :beta_testers) # requires type: group
Onni.drop_group!(:search_v2, :beta_testers)
Onni.level!(:homepage_banner, 25) # requires type: percentage
Onni.level!(:homepage_banner, 0) # soft zero, still ready
Onni.level(:homepage_banner)
Onni.visible_actor!(:selected_audience, user) # requires type: actors
Onni.drop_actor!(:selected_audience, user)
Onni.variants!(:new_checkout, {control: 50, treatment: 50})
Onni.variants(:new_checkout) # runtime override, then YAML default
Onni.variant(:new_checkout, user) # => :control / :treatment
Onni.register_group(:beta_testers) { |actor, _| actor.beta_tester? }
```

Each flag has one type: `group` (the default), `boolean`, `percentage`, `actors`,
or `experiment`. Declare types other than group explicitly. Use `type: boolean`
for a flag that is visible to everyone when ready. Defaults are `level: 0`
for percentages, `groups: []`, `actors: []` (stable actor IDs), and `variants: {}`.
Variant weights are relative nonnegative integers; a nonempty map needs a positive
total. Malformed definitions fail at load. Mutations for a different type raise
`ArgumentError` before writing.

Flags start pending even when YAML defaults match. `ready!` starts the declared
type; level zero, an empty audience, or empty experiment weights still make the
flag visible to nobody. `ready?`, `pending?`, and `parked?` inspect runtime power
without evaluating an actor or recording stats. A ready flag can return false
from `visible?`; expiry and conditions constrain visibility without changing power.

`park!` clears overrides and stores explicit parked hard-off. `clear!` clears
overrides and the power decision, returning to pending. Here pending means no
decision since creation or the latest clear, rather than a permanent history
claim. `ready!` after either operation restores YAML defaults. Unknown names
return false from all three power predicates and have no known power state.

Visible-slice commands also ready the flag. Drop-slice commands keep its current
power state and mask defaults with an override. `level!` readies a percentage
flag even at zero. `variants!` changes weights while preserving power, including
pending or parked. `Onni[name].power_state` reports `:ready`, `:pending`, or
`:parked`, and returns nil for unknown names.

Runtime settings override YAML defaults, including empty overrides. Existing
gate keys remain readable during migration. Ready and park commands store explicit power;
audience changes store complete overrides. Evaluation never ORs different audience types.

`Onni.exist?(name)` is adapter-backed (gates/feature rows). `Onni::Flag#exist?` is YAML-registry-backed.

## Stats

Each ready `visible?` / `variant` evaluation can record `shown_count` or `skip_count` into hourly buckets. Pending, parked, and unknown flags do not record stats. A ready zero-level rollout records skips. Counts measure evaluation calls, including repeated calls in one request; request/actor deduplication is deferred. Pass `record_stats: false` for inspect-only checks (the ActiveAdmin index does this). View history on the feature detail page. Stats are operational telemetry for experiments, not an audit log for authorization decisions.

Rows are created only when an evaluation is recorded for that flag and hour. Quiet hours leave no row.

### Instrumentation

Onni publishes `ActiveSupport::Notifications` events:

- `stats.record.onni` — a recorded evaluation (`:name`, `:shown`, `:weight`)
- `stats.purge.onni` — purge batch/drain result (`:deleted`, `:processed_count`, `:continued`)
- `feature_operation.onni` - mutations (`:feature_name`, `:operation`, `:result`; optional `:actor_id`, `:group_name`, `:level`). Operations: `ready`, `park`, `clear`, `visible_actor`, `drop_actor`, `visible_group`, `drop_group`, `level`, `variants`

```ruby
ActiveSupport::Notifications.subscribe(/\.onni$/) do |event|
  Rails.logger.info([event.name, event.payload].inspect)
end
```

`Onni.stats_overview` (also on the ActiveAdmin Flags page) reports bucket count, oldest hour, retention, and whether cleanup is overdue.

### Sampling

- `stats_sample_rate` is a float in `0.0..1.0` (clamped on assign). `1.0` records everything and skips `Random`.
- `stats_sampler` is an optional callable `|ctx|` with `ctx[:name]` and `ctx[:shown]`; return a rate, `true`/`false`, or `nil` to fall back to `stats_sample_rate`.
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

The Rails engine inserts `Onni::Middleware::RequestLifecycle`, which always calls `Onni.reset_request!` after each request (flushes `stats_buffer` when enabled, clears preload). Hosts that evaluate many flags per request can enable coalesced writes and optional preload:

```ruby
Onni.configuration.stats_buffer = true
Onni.configuration.request_preload = true # middleware calls Onni.preload! at request start
# Or preload a subset yourself: Onni.preload!(:new_checkout, :search_v2)
```

Manual `Onni.flush_stats!` / `Onni.reset_request!` remain available for non-Rails hosts or jobs. `gates_for_many` loads ActiveRecord gates in one `WHERE feature_key IN (...)` query. Memory adapter uses one lock section. Preload is fiber-local (safe with threads and fibers on Ruby 3.4+).

Request cleanup logs a stats-flush failure and clears request state while preserving the response or the application's original exception. Failed telemetry is best-effort; Onni does not retry a write whose outcome is uncertain. Call `Onni.flush_stats!` explicitly when the caller needs to handle persistence errors. The built-in adapters retain buffered sums of sampled weights, including totals above the per-evaluation weight limit.

### Gate cache and memory snapshots

Set `Onni.configuration.cache` to an ActiveSupport-compatible cache and set `cache_ttl` to bound entry lifetime. Each adapter instance uses its own cache namespace. A committed mutation advances a local feature generation before removing the old entry, so a delayed fill cannot restore that entry for later reads in the same process. Cleanup failure does not undo the committed mutation. Other processes do not share these generation counters; this mechanism provides no cross-process invalidation guarantee. Request preloads remain snapshots until reset or a local mutation.

Cache eviction rebuilds gate data from the adapter; evaluation combines it with the YAML definition. ActiveRecord rows persist runtime overrides. The memory adapter is ephemeral, so losing it also loses runtime overrides; YAML restores configured defaults only.

The memory adapter returns independent copies from `gates_for` and `gates_for_many` for nonempty rows. Evaluation can reuse its deeply frozen `gates_snapshot_for` result. Custom adapters may provide the same immutable snapshot capability; otherwise evaluation uses `gates_for`. Writes publish a new snapshot and isolate caller-owned strings. This moves some work from evaluations to mutations. See the [pressure episode](benchmarks/show_skip_pressure_binding.md) for measurements and limits.

### Concurrent stats writes (lock pressure)

Each kept sample upserts one hour bucket row keyed by `(feature_key, period, period_start)`. Concurrent writers that land on the same hour for the same flag serialize on that row (SQLite write lock / PostgreSQL row lock).

Historical measurements before the terminology revision used SQLite WAL (`benchmarks/stats_write.rb`, one hot key, 200 upserts per writer, median of 3 samples):

- W=1: direct ~0.036s (~5600 ops/s); buffer ~0.003s; sample 0.1 ~0.006s
- W=2: direct ~0.071s (~5600 ops/s); buffer ~0.004s; sample 0.1 ~0.009s
- W=8: direct ~0.275s (~5800 ops/s); buffer ~0.011s; sample 0.1 ~0.033s
- W=16: direct ~0.575s (~5600 ops/s); buffer ~0.023s; sample 0.1 ~0.064s

Inflection: from the second concurrent writer, wall time scales about linearly with writer count while direct upsert throughput stays flat (~5.5k-5.8k ops/s). That is lock queueing, not parallel write scaling. Busy/timeout errors need a short `busy_timeout` relative to queue depth; with a 5s timeout the usual symptom is latency bloat, not failed upserts.

For high request volume, prefer in order:

1. `stats_buffer = true` (engine middleware flushes at request end; measured ~25x less wall at 8 writers vs direct).
2. Lower `stats_sample_rate` or a per-flag `stats_sampler` / `stats_ignore` for the hottest keys.
3. Host DB settings: SQLite `timeout` + WAL; PostgreSQL pool sized for concurrency; never point many processes at one SQLite file without WAL.
4. Turn stats off (`stats_enabled = false`) when evaluation counts are not worth the write load.

Pressure binding: `benchmarks/stats_write_binding.md`.

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

Rough size: rows grow with `(flags that see traffic) x (hours with at least one recorded evaluation)`. Sampling (`stats_sample_rate`) and shorter retention shrink that. Prefer `stats_ignore` or a low `stats_sampler` rate for very hot flags before lengthening retention alone.

When the table is already large (about **>1GB** or **>10M rows**):

1. Schedule or run purge immediately; keep `stats_retention` at a value you actually query (admin default window is 24h).
2. Lower `stats_sample_rate` if you only need trend signal, not full counts.
3. After a large delete, run your database's maintenance (`VACUUM` on SQLite, `VACUUM` / `ANALYZE` on PostgreSQL, `OPTIMIZE TABLE` where relevant).
4. **Partitioning** (for example range partitions on `period_start`) is a host DDL choice. Onni does not manage partitions; keep the unique key `(feature_key, period, period_start)` and the purge predicate (`period_start < cutoff`) efficient. Dropping old partitions can replace row-by-row delete once you partition.
5. If stats are not worth the write load, set `stats_enabled = false` and truncate or drop the table.

### SQLite

SQLite is a first-class ActiveRecord dialect for Onni (dummy app, install migration, and CI). Evaluation writes use `INSERT ... ON CONFLICT DO UPDATE` with `excluded.updated_at` on the unique key `(feature_key, period, period_start)`.

Host tips:

- Prefer a file database, or `file:... ?mode=memory&cache=shared`. Plain `:memory:` gives each connection-pool checkout a private empty database, so upserts fail with a missing unique index.
- Set `timeout: 5000` (milliseconds) in `database.yml` so writers wait on locks under concurrent checkouts.
- For multi-process writers, enable WAL in the host (`PRAGMA journal_mode=WAL`).
- After a large purge, run `VACUUM`.

### Other ActiveRecord dialects

The ActiveRecord adapter builds `ON CONFLICT DO UPDATE` with bare `SET` targets and qualified existing-row values (`shown_count = onni_feature_stat_buckets.shown_count + ...`). PostgreSQL specifies existing-row access through the table name and proposed-row access through `excluded`; table-qualified assignment targets are invalid. See [PostgreSQL INSERT / ON CONFLICT](https://www.postgresql.org/docs/current/sql-insert.html#SQL-ON-CONFLICT). The specs execute this path on SQLite; PostgreSQL execution was not tested in this change. If another host dialect rejects the generated form, override `Adapters::ActiveRecord#record_stat` / `#record_stats_batch` or adapt its `on_duplicate` SQL.

## ActiveAdmin dashboard access

### Evaluation charts

Each feature detail page includes shown/skip evaluation charts, totals,
shown share, and an expandable data table. Choose Last 24 hours (hourly),
Last 7 days, or Last 30 days (daily). Times are UTC and include the current
incomplete period. The chart needs no JavaScript setup.

Counts describe evaluations, not unique users or A/B conversion results.
Sampling can produce estimates or raw sample counts. Periods without recorded
evaluations appear as zero; retention may have removed older history.

To replace the chart, add `app/views/admin/features/_chart.html.erb` in your
application. It receives an `Onni::VisibilityChart` as the `chart` local:

```erb
<p>Shown count: <%= chart.shown_count %></p>
<p>Skip count: <%= chart.skip_count %></p>
```

Use `chart.rows` for chronological points (`period_start`, `shown_count`,
`skip_count`, all string keys), `chart.hourly?` for the interval, and
`chart.shown_share` for the shown share (a fraction in 0..1, `nil` without evaluations).
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

Hosts that use Pundit/CanCanCan should also authorize ActiveAdmin page actions (`ready?`, `park?`, `feature?`, `update_feature?`) for the Features page. Park is a command name; `Onni.parked?` is the power-state predicate.

## Upgrading to terminology v1

Before deploying this code to an existing ActiveRecord host, stop evaluators and
stats writers and rename the existing columns without discarding historical data:

```sh
bin/rails generate onni:stats_rename
bin/rails db:migrate
```

New installs already use `shown_count` and `skip_count` and must skip this rename.
Hosts that already migrated to the transitional `show_count` / `skip_count`
schema must instead generate the separate follow-up migration:

```sh
bin/rails generate onni:shown_stats
bin/rails db:migrate
```

Choose the generator matching the current schema; do not run both for a fresh
upgrade. `onni:stats_rename` maps `enabled_hits` / `disabled_hits` directly to
`shown_count` / `skip_count`. `onni:shown_stats` maps only `show_count` to
`shown_count` and preserves `skip_count`.
Renaming preserves historical totals, including hard-off misses recorded by older
releases. New evaluations record powered misses only.
The migration is reversible. Coordinate rollback with the previous application
code; old and new writers cannot share the renamed schema during deployment.

Review every YAML flag before starting the updated application. A missing type
now means group; declare `type: boolean` for flags that previously relied on
global visibility from the implicit boolean type. Declare percentage, actors,
and experiment types explicitly. Existing
compatible legacy gates remain readable; incompatible audience gates do not grant
visibility. Update custom adapters to accept `record_stat(..., shown:)`, batches
with `shown_count`/`skip_count`, and atomic `update_gates(name) { |gates| ... }`.
The block receives mutable string-keyed rows and must commit them atomically.
The ActiveRecord adapter serializes mutations with a feature-row transaction;
the memory adapter holds its configured lock.

Update host policies to authorize `ready?`/`park?` page actions, custom sampler and
notification consumers to read `:shown`, and custom charts to use `VisibilityChart`,
`shown_count`, `skip_count`, and `shown_share`. Chart DOM attributes are
`data-onni-shown-count`, `data-onni-skip-count`, and `data-onni-shown-share`.
Admin POST routes are `/admin/features/ready` and `/admin/features/park`; scopes
are `all`/`ready`/`pending`/`parked`. Reserved feature names, including ready,
park, pending, visible, show, and skip, use `/admin/features/feature?key=`.

The v1 API removes enable/disable and transitional show/skip methods, including
Flag and Store evaluation aliases. Replace power changes with ready!/park!,
evaluation with visible?, audience changes with visible_*/drop_*, and percentage
reads/writes with level/level!. No start!/pause!, percentage read alias, or
drop_percentage! is provided. Zero level is an explicit level!(name, 0).
Existing empty gate sets cannot distinguish a historical hard-off from a never
started flag and are classified as pending. New park! writes an explicit marker.
No aliases remain for admin routes, stats columns, or event payloads.

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
Onni.ready!(:new_checkout)
```

## Migrating from another feature-flag library

Map your previous store into a source with `#feature_keys` and `#gates`, then import once. Keep `config/features.yml` keys aligned with the names you import. Unknown YAML keys are skipped. Declare one type per flag before importing. Unsupported, malformed, or type-incompatible gates are counted in `skipped_gates` and not written. Legacy boolean gates become explicit power; compatible audience rows retain their values.

```ruby
source = Onni::Migrator::Snapshot.new(
  feature_keys: %w[new_checkout homepage_banner],
  gates: [
    {feature_key: "new_checkout", key: "boolean", value: "true"},
    {feature_key: "homepage_banner", key: "percentage_of_actors", value: "25"}
  ]
)

Onni.migrate!(source)
# => { features:, gates:, skipped_gates: }
```

Any object that responds to `#feature_keys` and `#gates` works as a source; `Snapshot` is the built-in in-memory shape. Gate rows accept String or Symbol keys for `feature_key`, `key`, and `value`.

Imported gate keys: `boolean`, `actors`, `groups`, `percentage_of_actors`, `variants`.
Other gate keys from the prior library are skipped. Runtime variants override YAML defaults when both are present.
Replace call sites with `Onni.*` and remove the previous library when ready.

## Development

```bash
bundle install
bundle exec appraisal install
make test
```

Maintainers publish with `make release` (`usr/bin/release.rb`).
