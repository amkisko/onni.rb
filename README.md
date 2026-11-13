# onni

[![Test Status](https://github.com/amkisko/onni.rb/actions/workflows/test.yml/badge.svg)](https://github.com/amkisko/onni.rb/actions/workflows/test.yml)

Feature flags, gradual rollout, A/B variants, audience targeting groups, and shown/skip counts for any Ruby app. The core uses Ruby's standard library with zero runtime gem dependencies. ActiveRecord, Rails, notification delivery, and ActiveAdmin are opt-in extensions.

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
- The core has no runtime gem dependencies.
- Optional: ActiveSupport 7.2.3.2+ for notifications, ActiveRecord 7.2.3.2+ for persistence, or Rails 7.2.3.2+ for application integration.
- Optional: ActiveAdmin 4.0.0.beta23+ and below 5 for the dashboard.

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

For standalone Ruby, load the core and select your registry file:

```ruby
require "onni"
Onni.configuration.features_path = "config/features.yml"
Onni.ready!(:new_checkout)
```

The default registry path is `config/features.yml` relative to the working
directory. Definitions remain required for every mutation.

### Extensions

Extensions ship in the same gem. Install their external dependencies in the
host application and load the extension explicitly. An installed framework
does not change the behavior of `require "onni"`.

For Rails with ActiveRecord, load both integrations before application initialization:

```ruby
# Gemfile
gem "rails", ">= 7.2.3.2"
gem "onni", require: ["onni/rails", "onni/active_record"]
```

Then generate the registry, configuration, and schema:

```sh
bin/rails generate onni:install
bin/rails db:migrate
```

The generated initializer selects `:active_record` outside test. Rails integration
alone keeps the memory adapter; persistence requires the ActiveRecord extension
and `Onni.configuration.adapter = :active_record`.

For ActiveAdmin, use its extension instead:

```ruby
# Gemfile
gem "activeadmin", "4.0.0.beta23"
gem "onni", require: "onni/active_admin"
```

`onni/active_admin` loads the Rails, persistence, and notification integrations,
then registers the dashboard. The equivalent explicit `require` belongs before
Rails initializes. Loading `onni/rails` does not load the dashboard.

Without Rails, `require "onni/active_record"` provides the adapter and its models;
the host establishes the ActiveRecord connection and selects `:active_record`.
`require "onni/active_support"` installs only notification delivery.

Custom adapters register a factory with `Onni.register_adapter(:custom) { CustomAdapter.new }`,
then select `Onni.configuration.adapter = :custom`. Factories execute outside the
registration lock. The existing `Onni.adapter = instance` assignment also accepts
a host-owned adapter instance.

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

Keep the shared feature catalogue in `config/features.yml`. Document each flag's
intent with a description and expiration so the whole team can review it:

```yaml
new_checkout:
  expires_at: "2027-01-01"
  description: "Checkout redesign experiment"
  stats:
    enabled: true
    sample_rate: 1.0
```

A flag without audience filters stays closed. Add a registered
group with `Onni.visible_group!(:new_checkout, :beta_testers)` to make it visible
to that group's actors. `ready!` alone does not open an audience.

For an experiment with variants, declare its type explicitly instead:

```yaml
new_checkout:
  type: experiment
  groups: [beta_testers]
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
  groups: [beta_testers]
  expires_at: "2027-06-01"
  description: "New search UI for beta testers"
  conditions:
    - beta_tester?
    - beta_testers   # registered Onni group name
```

## Programmatic definitions

Prefer `features.yml` as the shared, reviewable catalogue. When a feature must
be declared in code, use the explicit API rather than editing registry internals:

```ruby
Onni.define!(:runtime_search,
  description: "Search rollout",
  expires_at: "2027-06-01",
  groups: ["beta_testers"],
  stats: {enabled: true})
```

`define!` requires a nonblank description and a parseable expiration string.
A new feature starts pending. Repeating the command replaces its programmatic
definition and retains stored power, runtime settings, and counters. Reusing
a name with existing adapter rows also retains those rows. YAML-owned names
cannot be shadowed. Unknown names still fail closed until explicitly defined.

These definitions belong to the current process, survive `Registry.reload!`
and adapter resets, and disappear at process exit. Define them in every worker
that evaluates them, preferably during shared initialization. The host owns
any durable source needed to recreate them. To move one into YAML, deploy its
YAML definition with a process restart; a reload collision raises. Existing
`Flag` instances remain metadata snapshots; request a fresh `Onni[name]` view
after changing a definition. See [RFC-0007](rfcs/0007-programmatic-feature-definitions.md).

## Runtime API

```ruby
Onni.visible?(:new_checkout, user)
Onni.visible?(:new_checkout, record_stats: false) # inspect without recording
Onni.ready!(:new_checkout) # power on with current settings
Onni.park!(:new_checkout) # hard-off; retain settings; evaluations still count
Onni.ready?(:new_checkout) # runtime power, independent of audience matching
Onni.pending?(:new_checkout) # no power decision since creation or clear!
Onni.parked?(:new_checkout) # explicit hard-off without evaluating an actor
Onni.clear!(:new_checkout) # remove overrides and restore pending
Onni.visible_group!(:search_v2, :beta_testers)
Onni.drop_group!(:search_v2, :beta_testers)
Onni.level!(:homepage_banner, 25)
Onni.level!(:homepage_banner, 0) # soft zero, still ready
Onni.level(:homepage_banner)
Onni.visible_actor!(:selected_audience, user)
Onni.drop_actor!(:selected_audience, user)
Onni.variants!(:new_checkout, {control: 50, treatment: 50})
Onni.variants(:new_checkout) # runtime override, then YAML default
Onni.variant(:new_checkout, user) # => :control / :treatment
Onni.register_group(:beta_testers) { |actor, _| actor.beta_tester? }
```

Ordinary flags have no type. Compose `everyone` (true/false), `groups`, `actors`,
`excluded_groups`, `excluded_actors`, and `level` (integer 0..100). All configured
filters must match. Entries within one include list are alternatives; any
excluded match rejects the actor. Excludes alone do not open an audience.

```ruby
Onni.filters!(:new_checkout, groups: ["beta_testers"], level: 25)
Onni.ready!(:new_checkout)
Onni.park!(:new_checkout)  # retain the cohort, percentage, and variant weights
Onni.ready!(:new_checkout) # resume the same rollout
Onni.filters!(:new_checkout, excluded_actors: [Onni::Actor.id(user)])
Onni.filters!(:new_checkout, level: nil) # remove only the percentage restriction
Onni[:new_checkout].filters # effective configured filters
```

`filters!` atomically changes only the supplied filters without changing power.
A nil removes that clause, including a YAML default. An empty include list is a
configured clause that matches nobody; a zero percentage also matches nobody.
An absent percentage imposes no percentage restriction. Dropping the last
include value keeps an empty clause; remove that clause with `filters!(name,
groups: nil)` or `actors: nil` when widening the audience is intended.

At least one positive opener is required: `everyone: true`, an include list,
or a percentage. `everyone: true` still intersects other filters. To move a
cohort rollout to everyone, explicitly remove restrictions that should no
longer apply:

```ruby
Onni.filters!(:new_checkout, everyone: true, groups: nil, actors: nil, level: nil)
```

This keeps excludes. Any actor-scoped filter, including an empty exclude list
or `level: 100`, requires an actor. Only the everyone opener without actor
filters can pass without an actor. YAML `conditions` retain their separate
actor-present behavior. Use filters for restrictions that must reject nil actors.

Experiments declare `type: experiment` and an explicit audience. `variants`
are relative nonnegative integer weights with a positive total, or an empty
map. Weights do not open visibility. `variant` first checks the same audience,
expiry, and conditions, then assigns a variant for an actor. Empty weights
return nil. Global percentages limit the audience; they are not variants.
Malformed definitions fail at load, and ordinary audience type names are rejected.

Flags start pending even when YAML defaults match. `ready?`, `pending?`, and
`parked?` inspect power without evaluating an actor or recording stats. A ready
flag can still be invisible to an actor. `park!` stores explicit hard-off while
retaining settings. `ready!` resumes those settings. `clear!` removes all
runtime overrides and the power decision, restoring YAML defaults in pending.
Unknown names return false from power predicates; `Onni[name].power_state`
returns nil for unknown names and otherwise `:ready`, `:pending`, or `:parked`.

Visible-slice commands add includes and ready the flag. Drops remove includes,
preserve power, and are not deny filters. `level!` sets a percentage and readies
the flag, even at zero. `variants!` preserves power and requires an experiment.
Runtime settings override YAML defaults, including empty and removed filters.
Existing gate keys remain readable; mixed audience gates now intersect.

`Onni.exist?(name)` is adapter-backed (gates/feature rows). `Onni::Flag#exist?` is YAML-registry-backed.

## Stats

By default, completed `visible?` calls for known flags record `shown_count` when
true and `skip_count` when false. Pending, parked, expired, and audience misses
all count as skips. Known `variant` calls count an assignment as shown and nil
as skipped, including missing actors and non-experiment flags. Unknown names
create no buckets. Power predicates and settings reads do not record calls.

Counts measure evaluations, including repeated calls in one request. They are
operational telemetry, not an authorization audit log or unique-actor analytics.
Historical periods keep their earlier counting scope; off-state calls recorded
from this change can lower `shown_share` relative to those periods.

```ruby
Onni.visible?(:new_checkout, user)                      # inherit collection settings
Onni.visible?(:new_checkout, user, record_stats: false) # inspect without collecting
Onni.visible?(:new_checkout, user, record_stats: true)  # opt in at this call site
Onni.stats!(:new_checkout, enabled: false)
Onni.stats!(:new_checkout, enabled: true, sample_rate: 0.25)
Onni.stats!(:new_checkout, enabled: nil, sample_rate: nil) # restore inherited defaults
Onni[:new_checkout].stats_settings
```

Feature YAML accepts `stats: {enabled: true, sample_rate: 1.0}`. Both fields are
optional: collection defaults to enabled, and an omitted rate inherits the
application rate. `stats!` changes only supplied fields atomically. Runtime nil
removes that override, restoring YAML or application defaults. Park retains
overrides; clear removes them. Field values are booleans and finite rates in
0..1; malformed fields raise before writes.

`record_stats: nil` inherits runtime feature enabled, then YAML enabled, then
true. Explicit false skips the call; explicit true overrides a feature opt-out.
The application `stats_enabled = false` and `stats_ignore` remain hard vetoes,
and sampling still applies. Rate defaults resolve runtime feature, YAML, then
application `stats_sample_rate`. A custom sampler may override the rate or
return nil to keep that resolved default. `stats_settings` describes defaults;
call-site choices and the custom sampler decide individual evaluations.
See [RFC-0006](rfcs/0006-evaluation-statistics-policy.md).

Rows are created only when an evaluation is recorded for that flag and hour. Quiet hours leave no row.

### Instrumentation

Load `onni/active_support` to publish these `ActiveSupport::Notifications` events
(the Rails extension includes this integration):

- `stats.record.onni` — a recorded evaluation (`:name`, `:shown`, `:weight`)
- `stats.purge.onni` — purge batch/drain result (`:deleted`, `:processed_count`, `:continued`)
- `feature_operation.onni` - mutations (`:feature_name`, `:operation`, `:result`; optional `:actor_id`, `:group_name`, `:level`). Operations: `ready`, `park`, `clear`, `visible_actor`, `drop_actor`, `visible_group`, `drop_group`, `level`, `variants`, `filters`, `stats`

```ruby
require "onni/active_support"

ActiveSupport::Notifications.subscribe(/\.onni$/) do |event|
  Rails.logger.info([event.name, event.payload].inspect)
end
```

The core leaves `configuration.instrumenter` and `configuration.logger` unset.
An instrumenter implements `instrument(name, payload) { |payload| ... }`; a logger
implements the ordinary `warn` and `error` methods. The core uses those configured
objects and does not discover a framework's logger or notification bus.

`Onni.stats_overview` (also on the ActiveAdmin Flags page) reports bucket count, oldest hour, retention, and whether cleanup is overdue.

### Sampling

- `stats_sample_rate` is a float in `0.0..1.0` (clamped on assign). `1.0` records everything and skips `Random`.
- `stats_sampler` is an optional callable `|ctx|` with `ctx[:name]` and `ctx[:shown]`; return a rate, `true`/`false`, or `nil` to keep the resolved feature/application sampling rate.
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

The Rails engine inserts `Onni::Middleware::RequestLifecycle`, which always calls `Onni.reset_request!` after each request (flushes accepted buffered counts and clears preload). Hosts that evaluate many flags per request can enable coalesced writes and optional preload:

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

Default retention is `config.stats_retention = 90 * 86_400` elapsed seconds.
Set a nonnegative Integer or nil; nil requires an explicit purge cutoff. Rails
hosts can convert a duration with `90.days.to_i`. Retention does not perform
calendar-day arithmetic across daylight-saving transitions. Install a batched
cleanup job and a `period_start` index:

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
releases. New evaluations also record pending and parked misses unless collection is disabled.
The migration is reversible. Coordinate rollback with the previous application
code; old and new writers cannot share the renamed schema during deployment.

Review every YAML flag before starting the updated application:

- Replace `type: boolean` with `everyone: true`.
- Remove `type: group`, `type: actors`, and `type: percentage`; retain their lists or level.
- Keep `type: experiment` and add an explicit audience, such as `groups` or `everyone: true`.
- Inspect stored mixed audiences: all present filters now intersect, including rows previously ignored by another type.
- Use `clear!` for a destructive reset; `park!` now preserves overrides.

No schema change is required for audience composition. Older library versions
cannot interpret the new filter mapping; migrate code and definitions together
and review stored filters before rollback. See [RFC-0005](rfcs/0005-audience-filter-composition.md).

Update custom adapters to accept `record_stat(..., shown:)`, batches
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

### Runtime application settings

Global statistics settings are live configuration. For example:

```ruby
Onni.configure do |config|
  config.stats_enabled = true
  config.stats_sample_rate = 0.5
end
```

Ordinary settings changes preserve the adapter, gates, and existing counts.
Adapter selection and concurrency changes rebuild the adapter; arrange a
deliberate transition and flush queued counts before changing their destination.
Turning buffering off preserves already accepted counts until request cleanup
or `flush_stats!`. Application-cache mutations advance generations even while
caching is disabled, so reattaching a cache cannot restore a pre-mutation gate.
Change `features_path` with a deliberate `Registry.reload!`; YAML file changes
also require that reload. Configuration is process-local, so apply application
changes in every worker. Persisted feature overrides retain the adapter's
documented cross-process cache freshness limits.

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

Or in host specs:

```ruby
require "onni/rspec"
Onni::RSpec.install! # before each example: memory adapter + reset_request!
```

## Migrating from another feature-flag library

Map your previous store into a source with `#feature_keys` and `#gates`, then import once. Keep `config/features.yml` keys aligned with the names you import. Unknown YAML keys are skipped. Declare the intended audience filters before importing. Unsupported or malformed gates are counted in `skipped_gates` and not written. Legacy boolean gates become explicit power (`powered`); audience rows retain their values and intersect.

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

### Cutover checklist

If the previous store combined gates with OR, review that expression explicitly:
Onni intersects all configured filters. Boolean source gates become power, not
an everyone audience opener. A global flag needs `everyone: true` in YAML or
`filters!(name, everyone: true)` after import.

1. List prior features and active gates (`boolean`, `groups`, `actors`, `percentage_of_actors`). Skip or re-model unsupported gates such as time-based percentages.
2. Write matching YAML keys with the intended filters. Register group names and align actor identifiers with `feature_actor_id` or `Class;id`.
3. Review mixed imported gates. Use `filters!` to remove clauses that should not restrict the target audience; no automatic OR conversion is provided.
4. For early access followed by everyone, set `everyone: true` and remove the include and percentage clauses that should no longer apply. Preserve excludes if still needed.
5. Import from two SQL tables (feature keys + gate rows) when the prior store used that shape:

```ruby
Onni.migrate!(
  Onni::Migrator::ActiveRecordTables.new(
    connection: ActiveRecord::Base.connection,
    features_table: "legacy_features",
    gates_table: "legacy_gates"
  )
)
# => { features:, gates:, skipped_gates: }
```

Column defaults are `key` on the features table and `feature_key` / `key` / `value` on the gates table. Override via constructor keywords when names differ. Or build an in-memory `Snapshot` from any export.
6. Compare `visible?` against the prior library for a sample of actors before removing old call sites.
7. Production stats: prefer `stats_buffer` and a sample rate below `1.0` (the install generator defaults to buffer on and rate `1.0`; choose a lower rate explicitly).

## Development

```bash
bundle install
bundle exec appraisal install
make test
```

Maintainers publish with `make release` (`usr/bin/release.rb`).
