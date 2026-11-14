# Delivery experiments, signals, and park reason

Design-only. Not committed work.

## Participants

Andrei Makarov.

## Decisions

Product goal: let hosts describe feature delivery as a reserved safe path
(`parked`) plus as many callable experiments as needed, route an actor into one
path with per-experiment audience/percentage, catch failures on experiments,
fall back to `parked`, accumulate integer signals via `observe!`, and `park!(reason:)` when a signal threshold is reached.
Ordinary `visible?` flags stay boolean. README must state Onni is for feature
delivery and experiments, not broad analytics, and must not name other products.

The safe path is named `parked` on purpose: it is the current / before-experiment
path, and it is what runs when power is parked. It is not an experiment and needs
no `experiment` declaration — only `def parked` or `parked do |...|`.

This generalizes binary attempt/fallback: that pair is `parked` + one experiment.
Multi-experiment routing is how complex conditioning stays out of ad-hoc `if`
trees while catalogue power/audience remain reviewable.

Desired loop:

1. Host implements `parked` and declares experiments (or thin two-path sugar).
2. Onni selects one experiment for the actor only when power is ready and the
   experiment audience matches; otherwise `parked`.
3. Run that path. On a rescued experiment exception: `observe!` a configured
   signal (default `:exception`, +1), run `parked` for this call, maybe
   `park!(reason:)` when the signal threshold is crossed. Rescue policy is
   narrower than bare StandardError (see below).
4. Stats: ordinary `visible?` shown/skip unchanged; signal levels are separate
   integer counters (see observe!). Optional delivery-shown instrumentation
   stays non-threshold telemetry if kept at all.
5. ActiveAdmin tunes per-experiment audience/percentage, signal thresholds,
   reset signals, and ordinary power (phased after API; see admin).

Audit resolutions from
[docs/reviews/20261114105728_guarded-experiments-plan-engineering-audit.md](../reviews/20261114105728_guarded-experiments-plan-engineering-audit.md)
are folded into the decisions below (findings 1-13).

### What Onni provides (layers + shared catalogue view)

Original reason for `features.yml`: one place everyone could read feature names,
descriptions, and schedules (`expires_at`) without hunting through app code.
Once Ruby (`define!` / Delivery `feature` kwargs) describes that same catalogue,
hand-authored YAML in the repo is no longer needed for that job.

README and RFCs present:

1. Programmable Ruby definitions = primary catalogue and delivery logic

   - Boolean / catalogue-only flags: `Onni.define!(...)` with the full validated
     field set (description, expires_at hygiene, raise_on_expiration, audience
     defaults, variants, stats, signals, …). Recommended for features with no
     Delivery paths.
   - Delivery: `Onni::Delivery` subclasses with `parked` + `experiment`
     methods/blocks. `feature :name, **settings` declares the same validated
     catalogue fields and owns the catalogue for that name. Prefer this for any
     multi-path or rescue/fallback feature — one class holds catalogue + paths.
   - Bare `feature :name` (no kwargs) only binds paths onto an existing
     catalogue entry (`define!` or compatibility YAML load).
   - Groups: `Onni.register_group`. Call sites: `visible?` / `Delivery.call`.
   - Unknown names stay fail-closed until registered in Ruby (or compatibility
     YAML load).

2. Runtime manipulation = live parameters and Onni records

   - Any feature parameter that the product exposes can be changed at runtime
     without redeploy: power (`ready!` / `park!` / `clear!`), audience filters,
     level, variants, stats policy, signal thresholds, per-experiment targeting,
     signal resets, and (with adapters) the underlying Onni records
     (feature rows, gate rows, stat/signal buckets).
   - Surfaces: Ruby API, ActiveAdmin, and anything that calls the same mutations.
   - Persistence: adapter gates/stats (memory ephemeral; ActiveRecord durable
     across processes subject to documented cache freshness limits).
   - Scope: Onni feature parameters and Onni adapter records — not arbitrary
     host application tables.

3. Catalogue export = the shared single list (replaces hand-authored YAML intent)

   - Export the effective catalogue (definitions + experiment declarations +
     useful runtime snapshot fields) so everyone can see one list of features
     and experiments without maintaining a second source of truth in the repo.
   - Formats: at least **YAML**, **JSON**, and **CSV**. Same logical payload;
     CSV may flatten experiments to rows (one row per feature or per
     feature+experiment — RFC picks the stable shape).
   - Surfaces: Ruby API (e.g. `Onni.export_catalogue(format:)` / string or IO),
     a shipped **rake task** for CI and ops, optional ActiveAdmin download.
     Hosts may commit an exported file in docs or CI artifacts if they want a
     reviewable dump; that file is **output**, not the definition owner.
   - Rake (required in the export slice). Prefer format-specific tasks so CI
     needs fewer env vars; still honor env on every task:
     - `rake onni:export` — generic; `FORMAT=yaml|json|csv` (default `yaml`)
     - `rake onni:export_yaml` / `onni:export_json` / `onni:export_csv` —
       fixed format aliases (ignore `FORMAT` or treat mismatch as error — RFC
       picks one; prefer ignore so aliases stay dumb wrappers)
     - optional `OUTPUT=path` on all (default stdout)
     All call the same `Onni.export_catalogue` API. Gem loads tasks via the
     engine/railtie (or documents `load` for non-Rails hosts).
   - Export includes descriptions, `expires_at`, signal threshold defaults,
     experiment names and class-default targeting, power/effective filters when
     a runtime snapshot mode is requested. Exact field list in the export RFC
     slice; secrets and actor payloads stay out.
   - ActiveAdmin index remains a live UI view of the same catalogue; export is
     the portable/offline form.

4. YAML **input** loader = compatibility only

   - Still load existing `features.yml` so legacy apps keep working. Same
     validated fields as `define!` / Delivery kwargs.
   - Not the recommended authoring path. Not where executable delivery code
     lives. Docs lead with Ruby; YAML load examples are migration/compatibility.
   - RFC-0007 "prefer features.yml" is superseded for new work. YAML as a
     **format** stays first-class via export; YAML as an **input catalogue**
     is compatibility until a later major can drop the loader.
   - Do not require apps to keep a hand-maintained `features.yml` once Ruby
     owns definitions.

### How definition, runtime, export, and compatibility load fit

Ownership split:

```text
define! / Delivery feature kwargs  -> primary definition catalogue (source of truth)
YAML/JSON/CSV export               -> generated shared list (read-only view)
YAML input loader                  -> compatibility catalogue owner (legacy apps)
Delivery class                     -> executable parked / experiment bodies
Adapter gates                      -> runtime overrides of catalogue defaults
Stat buckets                       -> evaluation / exception counters
Power (powered)                    -> ready / pending / parked
```

Resolution rules (effective settings):

1. A feature name has **one catalogue owner**: `define!`, or `Delivery`
   `feature :name, **settings`, or compatibility YAML **input**. Reload /
   registration raises on collision. Prefer Ruby for new features. Bare
   `feature :name` (no catalogue kwargs) does not claim ownership — it only
   attaches Delivery paths to an existing catalogue name.
2. Runtime gates override catalogue defaults field-by-field (same pattern as
   today's filters/stats/variants: gate present => gate wins; gate absent =>
   catalogue defaults from the owner). Class-declared experiment filters
   (`experiment :x, groups:, level:`) are always process-local path defaults:
   they are not auto-written to gates on boot. Admin/API shows the effective
   merge (class default then gate override). Gates appear only after an
   explicit mutation. No surprising publish-on-load writes (audit finding 8,
   option a).
3. `clear!` drops runtime overrides and the power decision: effective settings
   fall back to the catalogue owner defaults and power returns to pending.
   Historical stat buckets remain.
4. `park!` hard-offs power but retains runtime overrides so `ready!` resumes the
   same rollout. `Delivery.call` then always runs `parked`.
5. `Registry.reload!` reloads compatibility YAML **input** and keeps `define!` /
   Delivery-owned catalogue entries; still rejects input-YAML vs programmatic
   name collisions. Gate rows are not redefined by reload. Export is never
   fed back as a definition owner unless the host deliberately uses the
   compatibility loader on a file they maintain.
6. Migrating off YAML input: move fields into `define!` or Delivery `feature`
   kwargs, remove the input row, restart so the name has one owner. Use export
   when the team wants a single readable list.
7. Executable paths never live in YAML input or export dumps as runnable code.
   Changing `parked` / experiment bodies is a code deploy.
8. Workers: Ruby definitions and Delivery classes must be loaded in every
   evaluating process; compatibility YAML input is files on disk; durable
   gates/stats follow the adapter.
9. `feature :name, **settings` and `define!` validate with the same schema as
   YAML input (including `signals` when that schema lands). Experiment
   targeting keys (`groups`, `level`, …) stay on `experiment`, not on
   `feature`.
10. Export reads the registry + optional runtime snapshot; it does not mutate
    definitions. Format enum: `:yaml`, `:json`, `:csv` (symbols or string
    aliases). Stable column/key names so CI diffs stay useful. Rake tasks
    `onni:export` plus `onni:export_{yaml,json,csv}` are mandatory packaging
    for the export slice, not an optional extra.

Mental model for operators:

- Author features in Ruby: `define!` for boolean/catalogue-only, Delivery class
  (with `feature` kwargs) when paths and rescue matter.
- Run `rake onni:export_yaml` (or `onni:export FORMAT=…`, or open ActiveAdmin)
  when you need one list of all features and experiments for the whole app.
- Keep YAML **input** only while migrating a legacy `features.yml`.
- Call Ruby mutations / ActiveAdmin when today's rollout must move now (level,
  groups, park, signal thresholds, reset signals).

### Fact check (current tree)

Verified in this repository:

1. Evaluation records only `shown_count` and `skip_count` on hour buckets
   (`onni_feature_stat_buckets`). There is no `error_count` column, adapter field,
   chart series, or public record-error API.
2. `visible?` / `variant` finish before host feature code runs. Exceptions after a
   shown evaluation are invisible to Onni unless the host reports them.
3. Durable runtime settings live in adapter gates (`powered`, audience filters,
   `stats`, variants). `park!` writes `powered=false` and retains other settings.
4. `ActiveSupport::Notifications` (opt-in via `onni/active_support`) publishes
   `stats.record.onni` and `feature_operation.onni`. Notifications are telemetry;
   they do not change power across processes by themselves.
5. RFC-0006 already states that exceptions during evaluation must not invent a
   shown/skip outcome. That rule stays; error counts are a separate signal.
6. README "What Onni is not for" covers authorization only. It names Pundit and
   CanCanCan. A prior live-work note already asked public docs to stay free of
   third-party product names. Stats prose already says counts are operational
   telemetry, not unique-actor analytics, but does not say Onni is not a general
   analytics product.
7. Product version is `2.0.0`. Gate cache prefix is `onni/gates/v4/`. Next unused
   RFC id after 0007.

External prior art (checked against published docs; not copied as Onni API):

- LaunchDarkly: guarded rollouts and flag triggers can auto-remediate from metrics
  or APM webhooks (disable / roll back). Metric source is often external.
- Unleash: safeguards can pause rollouts from impact metrics (error rate, latency).
- Flipper Cloud circuit-breaker guide: flags used as manual kill switches; no
  built-in automatic error-rate parking in that guide.

### Blocks versus notification channel

In Onni vocabulary the durable unit is a gate row (the request's "block"). That
is the correct place for the limit and for the disable action.

- Store the exception policy as a gate (same pattern as the `stats` gate JSON).
- When the threshold trips, call the same durable path as `park!` (`powered=false`).
- Still emit `feature_operation.onni` after auto-park so hosts can alert. The
  notification is an effect, not the kill mechanism.

Relying on notifications alone fails closed poorly: a subscriber must reimplement
park, other processes keep serving until they see a gate write, and a missing
instrumenter leaves the feature live.

### Naming: `Onni::Delivery` (not `Onni::Guard`)

Glossary fit:

- Product job is feature **delivery** and experiments (AGENTS / README direction).
- Class runs `parked` + `experiment` paths: that is delivery routing, not auth.
- Threshold policy is **signal** / `observe!` based. Reusing Guard for the class
  would collide with auth metaphors and is rejected.

Rejected / weaker names:

- `Onni::Guard` - auth/circuit metaphor; clashes with metrics guards.
- `Onni::Feature` - taken by ActiveRecord `Onni::Feature`.
- `Onni::Rollout` - clashes with admin `RolloutForm`; sounds like audience-only.
- `Onni::Experiment` - clashes with DSL verb `experiment` and YAML
  `type: experiment`; underweights required `parked` path.
- `Onni::Variant` - existing assignment API, no host callables.

Chosen:

- Class: `Onni::Delivery`
- Sugar: `Onni.deliver(...)`
- Host subclasses: `CheckoutDelivery < Onni::Delivery`
- Keep **signal** + `observe!` + `park!(reason:)` for threshold kill policy only

### Layering: boolean core vs delivery experiments

Ordinary feature flags stay conditions and power: `visible?`, `ready!` / `park!`,
audience filters, level. Most call sites keep the boolean shape:

```ruby
if Onni.visible?(:new_checkout, user)
  NewCheckout.call!(order)
end
```

Today's YAML `type: experiment` + `variant` only assigns an arm name/weight. It
does not run host code. Delivery `experiment` DSL attaches callables and selects
one path per call. That stays opt-in; it must not force every flag into a router.

Fact: variants already solve sticky percentage splits without code. Delivery
experiments solve routing + execution + error fallback. Do not replace `variant`
in v1.

Variant vs Delivery matrix (audit finding 4; README/RFC glossary):

- Use `type: experiment` + `variant` when the host only needs a sticky arm name
  / weight and runs its own `case` / ifs.
- Use `Onni::Delivery` when Onni must run callables, fall back to `parked`, and
  apply signal thresholds / `park!(reason:)`.
- Admin labels: "Variant weights" vs "Delivery experiments" (never one list).
- Do not reuse the same arm name for a YAML variant and a Delivery experiment on
  one feature without an explicit bridge RFC. Reject collisions when both are
  configured.

### Experiments (N arms, reserved `parked` path)

Vocabulary: **experiment** = executable arm via `experiment`. **parked** = safe
path method/block, aligned with power `parked`. **Delivery** = Ruby class that
owns those paths. Do not call experiments "states" in the public DSL.

Hard invariant (audit finding 2): `Delivery.call` / `Onni.deliver` may always
run the `parked` path, including when power is pending or parked. Pending is not
a no-op for Delivery. Ordinary `visible?` stays false when not ready. Document
this divergence: boolean flags hide UI; Delivery keeps the legacy path live.

Rules:

1. Every Delivery class provides reserved path `parked` (current / before
   experiment / safe). Implement with `def parked(...)` or `parked do |...|`.
   Do not declare `experiment :parked`. No separate metadata line is required
   for parked. Power parked or pending, or not ready for experiments, or no
   matching experiment => run `parked`. Past `expires_at` does not force
   `parked` (see expires_at below).
2. Hosts declare any number of experiments. Names must not be `:parked`, `:on`
   (reserved for inline sugar), or other reserved tokens (call, feature,
   experiment, class, object, selected, deliver, ...). Reject at class load
   (audit finding 11).
3. Targeting for Delivery lives on each experiment only. Feature-level audience
   filters on the catalogue flag are not AND-ed into Delivery selection (avoids
   duplicated YAML). Power must be ready before any experiment can win; then
   each experiment's own groups/actors/excludes/level apply with the same
   composition rules as feature filters (AND across clauses; OR within an
   include list). Explicit opener required per experiment (audit finding 5).
4. Selection v1: among experiments whose filters match the actor, pick the
   first in declaration order. If none match, `parked`. Optional later: sticky
   weighted choice among the matched set (reuse variant hashing).
5. Only the selected path runs. Rescued error in an experiment falls back to
   `parked` for that call (not to another experiment). Exceptions from `parked`
   always propagate.
6. Threshold uses the feature power machine (`park!` => later calls run
   `parked`). Optional later: disable one experiment without parking the feature.
7. YAML/gates hold per-experiment audience overrides and signal threshold
   policy. Callable bodies live only in the Delivery class (or two-path sugar).

Rescue policy (audit findings 1 and 13):

- Do not rescue bare StandardError without exclusions. Exclude at least
  `ActiveRecord::Rollback` (it subclasses StandardError) and exit-like errors.
  Hosts must not wrap an open DB transaction inside Delivery experiment code
  expecting rollback to propagate through Onni.
- Default rescue set: StandardError minus the exclusion list. Instrument
  `error.class` and a truncated message via the configured instrumenter/logger;
  no actor ids on that payload beyond existing mutation allowlists.
- On rescued experiment exception: `observe!(name, :exception, 1)` by default
  (or a signal configured on the Delivery/feature), then maybe `park!(reason:)`.
  Programming errors (`NoMethodError`, `NameError`) still fall back to `parked`
  but by default do not `observe!` toward the park threshold (configurable).

### `expires_at` is developer hygiene only

Current product (fact): past or unparseable `expires_at` fail-closes `visible?` /
`variant` (`Store#expired?`). ActiveAdmin still shows the date.

Change: `expires_at` must not affect visibility, experiment selection, stats, or
power. It is a maintainer signal that the flag or experiment catalogue entry is
stale.

Warning modes (combine freely). Do **not** raise on application boot or registry
load: an overdue flag must not take down processes. Catch staleness in CI/specs.

1. Visual: ActiveAdmin (and Flag helpers) mark overdue / unparseable expiry.
2. Console: optional `configuration.logger&.warn` when an overdue definition is
   first used or when an explicit verify runs — never as a boot killer.
3. Spec / test suite (preferred place to fail hard):

   - `Onni.verify_expirations!` (or `Onni::RSpec` example) raises listing overdue
     / unparseable features. Hosts call it from a dedicated spec or CI step.
   - Per feature opt-in to that check: YAML / `define!` field
     `raise_on_expiration: true` (clearer than bare `strict: true`). When the
     verify runs, only those features (or all features if a global verify mode
     is chosen) are required to be non-overdue.
   - Application helper: `configuration.expires_at_verify = :opt_in | :all`
     (RFC names). Default `:opt_in` so only flagged features fail the suite.
   - Still not an evaluation gate: `visible?` / Delivery ignore expiry.

Example:

```yaml
new_checkout:
  expires_at: "2026-06-01"
  raise_on_expiration: true
  everyone: true
```

```ruby
# spec/onni/expirations_spec.rb (host or gem)
RSpec.describe "Onni feature expirations" do
  it "has no overdue opted-in features" do
    Onni.verify_expirations!
  end
end
```

Unparseable dates: fail `define!` validation when metadata is required; at YAML
load prefer warn + mark invalid for verify/admin rather than aborting boot.
Evaluation paths stop calling `expired?` as a visibility gate.

This is a breaking contract change relative to the fail-closed behaviour and
needs explicit changelog / migration note (shown_share and skip counts for
overdue flags will change once they start recording shown again).

### Machines (name them; do not invent a second power model)

Durable power machine (existing; kill switch for the whole feature):

```text
pending --ready!--> ready --park!--> parked
ready   <--ready!-- parked
*       --clear!--> pending
```

- Auto-threshold and manual/external kills use `park!(reason:)` (e.g. `signal:exception`, `operator`).
  Reason is optional instrumentation on the existing park mutation; no separate `trip!` API.
- Power parked means selection always runs the `parked` path.
- No half-open auto-ready. `reset_signals!` (or per-signal reset) clears signal
  levels only.

Per-call selection machine (ephemeral):

```text
start -> select
select --not ready / no match--> run parked -> done
select --experiment-----------> run experiment
run experiment --ok-----------> done
run experiment --rescued------> observe!(:exception, +1) -> (maybe park! reason:) -> run parked -> done
run parked --raises-----------> propagate
```

Observe / park (replaces error! / error_rate / trip!; audit finding 3 reframed):

- Host (or Delivery rescue) calls `observe!` with integer deltas. Onni does not
  compute rates, percentiles, or float metrics.
- When a signal's level reaches its threshold, `park!(reason: "signal:<key>")`.
- Ordinary `visible?` shown/skip remain separate and unchanged.

Admin tunes per-experiment filters/level, signal thresholds, reset signals, and
power. Admin does not edit Ruby `parked` / experiment method bodies.
UI must label power parked vs delivery path `parked` distinctly; Reset signal
must not look like Ready.

### Recommended APIs

Delivery class is the primary multi-experiment surface (GraphQL-field style).
Inline two-path sugar covers simple experiment-vs-current without nested builders.

Class: declare experiments with metadata; implement `parked` plus a method per
experiment name. No nested `def call`. Never `experiment :parked`.

```ruby
class CheckoutDelivery < Onni::Delivery
  # preferred: class owns catalogue + paths (same fields as define! / YAML)
  feature :new_checkout,
    description: "Checkout redesign with safe legacy fallback",
    expires_at: "2027-06-01",
    raise_on_expiration: true,
    signals: { exception: { threshold: 25 } }

  # compatibility: bare `feature :new_checkout` if YAML/define! already owns the name

  experiment :checkout_v2, groups: %w[beta_testers], level: 25
  experiment :checkout_v3, groups: %w[internal], level: 100

  def parked(order:)
    LegacyCheckout.call!(order)
  end

  def checkout_v2(order:)
    CheckoutV2.call!(order)
  end

  def checkout_v3(order:)
    CheckoutV3.call!(order)
  end
end

# equivalent parked body:
# parked do |order:|
#   LegacyCheckout.call!(order)
# end

receipt = CheckoutDelivery.call(current_user, order: order)
# => always one value: whichever path ran for this actor/kwargs
```

Optional short form for a tiny experiment body:
`experiment :checkout_v2, level: 25 do |order:| ... end`
still must not introduce an inner `def call`.

Two-path sugar (`parked` + one experiment block). The block is the reserved
experiment name `:on` (audit finding 9), so admin/gates can target `:on` and
`selected` stays meaningful:

```ruby
result = Onni.deliver(:new_checkout, current_user, parked: -> { LegacyCheckout.call!(order) }) do
  CheckoutV2.call!(order)
end
# always one result for these parameters (actor + kwargs captured in callables)
# :on success -> block value; otherwise parked callable value
# selected -> :parked or :on (inspection only; not part of the return)
```

Rules:

1. `parked` body is required (`def parked` or `parked do`). Zero or more
   `experiment` declarations are allowed (zero => always parked). Inline sugar
   requires `parked:` plus a block mapped to experiment `:on`.
2. Selection and execution share one executor for class and sugar.
3. Return value: `Delivery.call` / `Onni.deliver` always return **exactly one**
   result — the return value of the single path that ran. Which path runs
   depends on parameters (actor, power, experiment filters, kwargs forwarded to
   that method). Never both experiment and parked values, never an array of
   alternatives, never a Result/Either wrapper in v1. After a rescued experiment
   failure, that one result is from `parked`. If `parked` raises, the exception
   propagates (no return value).
4. No nested attempt/fallback builder.
5. Catalogue fields (including signal thresholds) come from the catalogue owner
   (YAML, `define!`, or `feature :name, **settings`) and from gates /
   ActiveAdmin at runtime. Class-declared `experiment` filters are process-local
   path defaults until an explicit mutation writes gates (see resolution
   rules 1-2, 9).
6. `Onni::Flag` stays a read model.
7. `Onni.selected(name, actor)` requires a registered Delivery class for that
   feature (or the inline `:on` convention when only sugar is used in-process).
8. Do not put the same name in YAML and in `feature ..., **settings` /
   `define!` — one catalogue owner (rule 1).

### Signals: `observe!` and `park!(reason:)` (no `error!`, no `trip!`, no float metrics)

```ruby
Onni.observe!(:new_checkout, :exception, 1)   # increase toward threshold
Onni.observe!(:new_checkout, :exception, -1)  # decrease / heal
Onni.signal!(:new_checkout, :exception)       # optional sugar: observe!(..., 1)
Onni.park!(:new_checkout, reason: "signal:exception")
Onni.park!(:new_checkout)               # same as today; reason optional
Onni.reset_signals!(:new_checkout)
Onni.signal_level(:new_checkout, :exception)
Onni.selected(:new_checkout, actor) # => :parked / :checkout_v2 / :on / ...
```

Prefer `observe!`. Optional `signal!(name, key)` is +1 sugar. No `error!`.
No separate `trip!`: extend existing `park!(name, reason: nil)` so auto-threshold,
Admin, and external monitors all call the same mutation. Reason flows into
`feature_operation.onni` (and logs); omit reason for ordinary operator park.

Semantics:

Naming (do not confuse):

- `parked` = Delivery safe path (legacy code method).
- `park!` = power mutation (close the gate).
- `:exception` = default signal key that Delivery bumps when it rescues a
  StandardError from an experiment. Crossing its threshold calls `park!`.
  Named for Ruby's exception vocabulary, not for power `park!` or path `parked`.

What closes the gate (power -> parked)?

- Only `park!` closes the gate. Signals never invent a second power state.
- **Automatic / programmatic close:** after `observe!`, if that signal key has a
  configured integer `threshold` and `signal_level >= threshold` and power is
  ready, Onni calls `park!(reason: "signal:<key>")`.
- **Delivery built-in:** on rescued experiment exception, Onni always
  `observe!(name, :exception, 1)`. So the reserved signal **`:exception`** is the
  default   path from Delivery rescue to automatic gate close - but only if the
  catalogue owner or gates define `signals.exception.threshold`. Without that
  threshold,
  rescue still runs the `parked` *path* for the call and bumps the counter,
  yet does not `park!` power.
- **Other keys** (`:hold`, `:pause`, product names): same rule. They auto-close
  the gate only if they have their own `threshold`. No threshold => observe-only
  bookkeeping. Hosts that want "hold means close" either set a threshold on
  `:hold` or call `park!(reason:)` themselves after their own math.
- Manual close: `park!(reason: "operator")` (or any reason) without touching
  signals.

```text
observe!(feature, key, delta)
  -> update level(key)
  -> if signals[key].threshold present AND level >= threshold AND ready?
       -> park!(reason: "signal:<key>")
```

- A **signal** is a named integer level (allowlisted keys). Not a power state.
- `observe!(name, signal, delta)` applies a signed integer delta (default +1).
  The developer decides when/how much to bump or reduce. Onni does not take
  floats, ratios, or latency aggregates.
- `park!` remains idempotent if already parked. Reason does not change power
  semantics.
- Omit all signal thresholds => Delivery still falls back to the `parked` path
  on rescue and may still count `:exception` if observed, but never auto-`park!`.
- Levels stick until negative `observe!` or `reset_signals!`. No silent
  hour-window heal in v1.
- Keep ordinary `visible?` shown/skip for evaluation telemetry. Signals are
  separate. Optional Delivery path instrumentation must not drive park math.
- Kill-switch freshness: same gate-cache limits; short `cache_ttl` or no cache
  when fleet-wide park must be fast. Cache prefix bump when signal policy lands
  in gate snapshots.
- Hot path: one observe write; possible park gate write. Bench after RFC B.

Preferred (Ruby catalogue owner):

```ruby
feature :new_checkout, signals: { exception: { threshold: 10 } }
# or Onni.define!(:new_checkout, ..., signals: { exception: { threshold: 10 } })
```

Compatibility YAML (same schema; do not also register the name in Ruby):

```yaml
new_checkout:
  signals:
    exception:
      threshold: 10
```

Runtime mutation shape in RFC (`signals!` or per-key updates). Storage: compact
per-feature signal levels (gate JSON and/or small adapter rows), not an
analytics warehouse. External APM: host calls `observe!` or `park!(reason:)`; no gem
adapters.

Operator targeting: Ruby API first; ActiveAdmin phased (thresholds, levels,
reset, park with reason, ready/park; power vs path labels; catalogue export
download). Catalogue export API + `rake onni:export` /
`onni:export_{yaml,json,csv}` in Phase 3b.

Non-goals:

- Turning every `visible?` into an implicit rescue boundary.
- Embedding experiment method bodies in YAML or ActiveAdmin.
- Requiring hand-authored YAML input for new features once Delivery/`define!`
  can own the catalogue.
- Treating an exported YAML/JSON/CSV file as the definition owner (export is
  output only unless the host feeds a file into the compatibility loader on
  purpose).
- Removing the YAML **input** loader in this plan (compatibility stays until a
  later major).
- Making feature classes mandatory for ordinary boolean flags.
- Replacing `variant` assignment API in the first cut.
- Declaring `experiment :parked` or falling back from one experiment into another.
- A GraphQL-ruby extension for these classes.
- Global rescue_from / APM drain ingestion.
- Swallowing `parked` path failures.
- Catching Exception / SystemExit / NoMemoryError.
- Rescuing ActiveRecord::Rollback (or relying on Delivery around open transactions).
- Soft level! 0 instead of park for the whole-feature threshold in v1.
- A parallel circuit-breaker power enum beside ready/pending/parked.
- Automatic half-open probing or re-ready without explicit ready!.
- Using `expires_at` as a runtime kill switch or audience gate.
- Broad analytics / float metrics / `error!` / `trip!` / multi-metric guard DSL /
  third-party names in README.
- Scraping external APM inside the gem or unbounded signal cardinality.

### README scope (can ship ahead of code)

Under "What Onni is for" / "What Onni is not for":

- State that Onni is for feature delivery, gradual rollout, experiments, and
  operational evaluation counts that support those jobs.
- State that Onni is not a general analytics, product analytics, or error-tracking
  platform; hosts keep APM and analytics elsewhere.
- Replace named policy libraries with generic wording ("host policy layer",
  "authorization gem or middleware").
- Keep the migrator section generic (gate key names only; no peer product names).

### Implementation phases

Split RFCs (audit finding 10). Do not bundle expires_at, signals/park reason, and
Delivery DSL into one first cut.

Phase 0 - README: analytics/not-for scope, no third-party product names; Ruby
primary catalogue; YAML input = compatibility; shared list via export
(YAML/JSON/CSV); variant vs Delivery matrix stub. Copy-only OK.

RFC A / Phase 0b - `expires_at` hygiene only: remove evaluation fail-closed;
visual + optional warn; `verify_expirations!` + `raise_on_expiration` for the
spec/CI suite (no boot raise); update specs, audience matrix, README, changelog.
Mark lineage dependents stale (store expiry examples, matrix).

RFC B / Phase 1 - `observe!` / optional `signal!` + signal thresholds +
`park!(reason:)` + `reset_signals!` / `signal_level`. Specs before schema.
Kill-switch cache freshness documented. Observe/park bench. Minimal admin
optional (Park with reason + signal levels).

RFC C / Phase 2 - `Onni::Delivery` + `Onni.deliver` (`:on` sugar), reserved
`parked`, rescue -> `observe!(..., :exception, 1)`, selection rules, `selected`,
class-default merge without auto-publish. Specs before code. Admin not required
to prove executor.

Phase 3 - N experiments: per-experiment groups/level gates, admin tuning,
clearer power vs path UI. Selection = first match.

Phase 3b / export RFC slice - `Onni.export_catalogue` for `:yaml`, `:json`,
`:csv`; ship rake `onni:export` (FORMAT + OUTPUT env) and aliases
`onni:export_yaml`, `onni:export_json`, `onni:export_csv` (OUTPUT env;
stdout default); optional ActiveAdmin download; stable keys/columns;
definition snapshot vs optional runtime-effective mode. Specs for golden
fixtures per format and for rake tasks (alias vs FORMAT, stdout vs file).
Can ship after RFC C once Delivery experiment rows exist in the registry
view; CSV flattening shape locked in that RFC.

Phase 4 - Optional: sticky experiment weights; disable one experiment without
full feature park. No float-metrics expansion.

### SaaS use-case examples

Illustrative host code. Names stay generic. Authorization stays in the host
policy layer; Onni only decides delivery path and rollout power. Examples lead
with Ruby catalogue ownership. YAML is shown only under compatibility notes.

#### 1) Promo banner (boolean only, `define!`)

No Delivery class. Register catalogue in Ruby; gate visibility in the view.

```ruby
# config/initializers/onni_features.rb (or eager-load path)
Onni.define!(
  :homepage_banner,
  description: "Seasonal homepage promo strip",
  expires_at: "2027-03-01",
  everyone: true
)

# after deploy
Onni.ready!(:homepage_banner)

# app/views/layouts/application.html.erb (sketch)
<% if Onni.visible?(:homepage_banner, current_user) %>
  <%= render "promos/homepage_banner" %>
<% end %>
```

Operator: park from ActiveAdmin when the campaign ends; `clear!` returns to
pending against the `define!` defaults. CI: not opted into
`raise_on_expiration`, so verify may skip it under `:opt_in`.

Compatibility: the same fields may still live in `features.yml` instead of
`define!` for legacy apps (one owner; do not duplicate).

#### 2) Checkout redesign (Delivery-owned catalogue + `:exception` signal)

Problem: ship a new checkout while keeping legacy checkout as the always-safe
path. Internal staff see v3 first; beta cohort sees v2 at 25%; everyone else
stays on legacy until ready and matched. Rescued exceptions bump `:exception`
and may power-park.

```ruby
class CheckoutDelivery < Onni::Delivery
  feature :new_checkout,
    description: "Checkout redesign with safe legacy fallback",
    expires_at: "2027-06-01",
    raise_on_expiration: true,
    signals: {
      exception: { threshold: 25 }
    }

  experiment :checkout_v3, groups: %w[internal]
  experiment :checkout_v2, groups: %w[beta_testers], level: 25

  def parked(order:)
    LegacyCheckout.complete!(order)
  end

  def checkout_v2(order:)
    CheckoutV2.complete!(order)
  end

  def checkout_v3(order:)
    CheckoutV3.complete!(order)
  end
end

# config/initializers/onni_groups.rb
Onni.register_group(:beta_testers) { |actor, _| actor.beta_tester? }
Onni.register_group(:internal) { |actor, _| actor.staff? }

# checkout controller
def create
  order = Order.create!(checkout_params)
  # one return value for this user/order — v3, v2, or legacy
  result = CheckoutDelivery.call(current_user, order: order)
  redirect_to result.receipt_path
end
```

Day-0 operator path:

1. Deploy Delivery class + group registration in every worker (no YAML row).
2. `Onni.ready!(:new_checkout)` when staff should start hitting v3.
3. Widen: ActiveAdmin or `Onni` API adjusts experiment filters (e.g. raise v2
   level to 50, later add `everyone` opener on an experiment — exact mutation
   helpers in RFC C).
4. If payments error in v2/v3: Delivery rescues, `observe!(:new_checkout, :exception, 1)`,
   returns legacy `parked` result for that request. At 25, auto
   `park!(reason: "signal:exception")`; later calls always run `parked`.
5. Host can also observe from a payment webhook without Delivery:

```ruby
# payment webhook
Onni.observe!(:new_checkout, :exception, 1) if event.checkout_failed?
```

6. Incident: `Onni.park!(:new_checkout, reason: "operator")` then fix, then
   `Onni.reset_signals!(:new_checkout)` and `Onni.ready!(:new_checkout)`.
7. CI: `Onni.verify_expirations!` fails once `expires_at` passes because
   `raise_on_expiration: true`.

Compatibility: bare `feature :new_checkout` plus a YAML/`define!` catalogue row
is supported for migration; preferred form is kwargs on the Delivery class.

#### 3) Search results (two experiments, Delivery-owned catalogue)

Problem: try a new ranking UI for beta, a denser layout for 10% of remaining
actors, legacy list otherwise. Catalogue and paths live on the class.

```ruby
class SearchDelivery < Onni::Delivery
  feature :search_v2,
    description: "Search results layout experiments",
    expires_at: "2027-04-15",
    signals: {
      exception: { threshold: 40 }
    }

  experiment :ranking_ui, groups: %w[beta_testers]
  experiment :dense_layout, level: 10

  def parked(query:, page:)
    Search::LegacyResults.call(query: query, page: page)
  end

  def ranking_ui(query:, page:)
    Search::RankingResults.call(query: query, page: page)
  end

  def dense_layout(query:, page:)
    Search::DenseResults.call(query: query, page: page)
  end
end

# search controller — host does not rescue here; Delivery executor does
def index
  @results = SearchDelivery.call(
    current_user,
    query: params[:q],
    page: params[:page]
  )
end
```

Selection: ready required; first matching experiment wins (`ranking_ui` before
`dense_layout`). A beta user never hits dense_layout.

Exceptions: yes for experiment methods only. If `ranking_ui` or `dense_layout`
raises (StandardError minus exclusions such as ActiveRecord::Rollback), the
Delivery executor catches it, `observe!(:search_v2, :exception, 1)`, runs `parked`,
and returns that one legacy result. Host code above stays unaware. `parked`
itself is not rescued by Delivery — its exceptions propagate. Programming
errors still fall back to `parked` but by default do not bump the `:exception`
signal toward auto-`park!`.

Inline sugar when there is only one new path:

```ruby
@results = Onni.deliver(
  :search_v2,
  current_user,
  parked: -> { Search::LegacyResults.call(query: params[:q], page: params[:page]) }
) do
  Search::RankingResults.call(query: params[:q], page: params[:page])
end
# experiment name :on; tune audience for :on via gates/admin
```

#### 4) Invoice PDF renderer (background-ish request, explicit observe)

Problem: new PDF engine; finance team must not see blank invoices. Controller
uses Delivery; a Sidekiq retry path observes without re-entering Delivery.

```ruby
class InvoicePdfDelivery < Onni::Delivery
  feature :invoice_pdf,
    description: "PDF renderer swap for invoices",
    expires_at: "2027-02-01",
    signals: { exception: { threshold: 10 } }

  experiment :prince_v2, groups: %w[internal], level: 100

  def parked(invoice:)
    InvoicePdf::Prawn.render(invoice)
  end

  def prince_v2(invoice:)
    InvoicePdf::Prince.render(invoice)
  end
end

pdf = InvoicePdfDelivery.call(current_user, invoice: invoice)
send_data pdf, type: "application/pdf"
```

```ruby
# app/jobs/regenerate_invoice_pdf_job.rb
def perform(invoice_id)
  invoice = Invoice.find(invoice_id)
  InvoicePdf::Prince.render(invoice)
rescue InvoicePdf::EngineError
  Onni.observe!(:invoice_pdf, :exception, 1)
  InvoicePdf::Prawn.render(invoice)
end
```

Low threshold (10) so a bad renderer parks quickly. Operator resets signals after
hotfix before `ready!`.

#### 5) Weekly digest mailer (boolean gate + host signal math)

Problem: new HTML digest. Job uses `visible?` for cohort; failures are counted by
the host (rate logic owned by the app, not Onni floats).

```ruby
Onni.define!(
  :digest_mailer,
  description: "Weekly digest template",
  expires_at: "2027-05-01",
  everyone: true,
  signals: { exception: { threshold: 15 } }
)

class WeeklyDigestJob < ApplicationJob
  def perform(user_id)
    user = User.find(user_id)
    return unless Onni.visible?(:digest_mailer, user)

    DigestMailer.weekly(user).deliver_now
  rescue Net::SMTPServerBusy
    Onni.observe!(:digest_mailer, :exception, 1)
    raise
  end
end
```

App may choose to observe only every Nth failure:

```ruby
Onni.observe!(:digest_mailer, :exception, 1) if (user.id % 10).zero?
```

At threshold 15, Onni parks; later `visible?` is false (power parked) so digests
stop for everyone until `ready!`. No Delivery class required.

#### 6) Expiration hygiene in CI

```ruby
# spec/onni/expirations_spec.rb
RSpec.describe "Onni feature expirations" do
  it "rejects overdue opted-in catalogue entries" do
    Onni.verify_expirations!
  end
end
```

`new_checkout` fails the suite after 2027-06-01 until the Delivery catalogue
`expires_at` is extended or `raise_on_expiration` is removed. Boot and
production processes do not raise.

#### 7) Operator cheat sheet (same features)

```text
Widen checkout v2 cohort     -> Admin / filters! on experiment checkout_v2
Kill checkout now            -> park!(:new_checkout, reason: "operator")
See why it auto-parked       -> reason signal:exception on feature_operation; signal_level
Clear failure budget         -> reset_signals!(:new_checkout) then ready!
Campaign banner off          -> park!(:homepage_banner) or clear! after end date
Check stale flags in CI      -> verify_expirations!
List all features            -> rake onni:export_yaml (or onni:export FORMAT=…)
```

```bash
# shared readable catalogue (generated; not the definition owner)
bundle exec rake onni:export_yaml
bundle exec rake onni:export_json OUTPUT=tmp/onni_catalogue.json
bundle exec rake onni:export_csv OUTPUT=tmp/onni_catalogue.csv
# generic + env still supported
bundle exec rake onni:export FORMAT=yaml
bundle exec rake onni:export FORMAT=csv OUTPUT=tmp/onni_catalogue.csv
```

```ruby
Onni.export_catalogue(format: :yaml) # same payload as the rake tasks
```

After any `park!`, Delivery selection always runs the `parked` method; boolean
`visible?` stays false while power is parked.

## Effects

Design-only; no product code from this note. Plan now uses integer signals +
`observe!` + `park!(reason:)`; default rescue signal `:exception`; Ruby
(`define!` / Delivery `feature` kwargs) is the catalogue source of truth;
hand-authored YAML input is compatibility only; the original "everyone can see
descriptions and schedules" job moves to catalogue **export** (YAML, JSON,
CSV) plus Admin; RFC-0007 "prefer features.yml" superseded for new work; one
catalogue owner per name; audit findings 1-13 remain incorporated.

## Next

- Open live-work issue; claim RFC A (expires_at), then B (observe/park reason),
  then C (Delivery DSL), then export slice (yaml/json/csv); specs before each
  implementation slice.
- Optional early Phase 0 README patch (Ruby-first + export replaces shared YAML
  intent).
- Re-audit after RFC C / export draft against this plan.

## Source

- [Engineering audit](../reviews/20261114105728_guarded-experiments-plan-engineering-audit.md)
- Operator clarification: Ruby-first catalogue; YAML input compatibility;
  catalogue export yaml/json/csv + rake onni:export / onni:export_*;
  observe!/signals;
  park!(reason:) not trip!; default signal `:exception`; one catalogue owner;
  expires_at warn-only; README scope; naming `Onni::Delivery`
- Earlier request (exception rate floor, blocks vs notifications, README scope)
- [GraphQL no first-class extension](20261113184244_graphql-ruby-no-first-class-extension.md)
- [RFC-0007 programmatic definitions](../../rfcs/0007-programmatic-feature-definitions.md)
- [RFC-0006](../../rfcs/0006-evaluation-statistics-policy.md)
- [Evaluation stats issue](../issues/20261113174758_evaluation-stats-and-runtime-definitions.md)
- [Support gaps note on third-party names](../issues/20261112085000_support-gaps-vs-peers.md)
- lib/onni/store.rb, mutations.rb, stats.rb, adapters/*/stat*, create_onni_features template
- LaunchDarkly runtime controls / guarded rollouts docs; Unleash feature-flag
  automation blog; Flipper circuit-breaker guide (manual kill-switch framing)
