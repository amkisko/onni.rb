# Guarded experiments plan engineering audit

## Participants

Andrei Makarov.

## Decisions

Audit target: design-only plan
`docs/plans/20261114103806_exception-rate-park-and-error-stats.md`.
No Guard implementation exists yet. Findings judge the proposed contract against
the current tree (Store, gates, stats, power FSM) and stated phases.

Modes: contract, lineage (published numbers and identifiers), product-surface
(ActiveAdmin), observability (notifications), security (trust around swallowed
errors and admin mutations), performance/resource as design inference against
existing stats-write evidence. Boundary/control: operator + multi-process
adapters. Resource and trace modes for a future executable Guard path are
design inferences; no new bytes to bench. Learned-systems skipped (no model).
Dependency-audit skipped (no package change in the plan).

### Ranked findings

1. Severity: high. Confidence: high. Location: proposed `Onni.guard` /
   Guard executor rescue StandardError.
   Why: ActiveRecord::Rollback subclasses StandardError. Rescuing StandardError
   around host experiment code inside a request transaction can swallow an
   intentional rollback and then run `parked`, leaving partial writes or wrong
   control flow. Evidence: observed (`ActiveRecord::Rollback.ancestors` includes
   StandardError). Kind: observed (ancestor) + inference (host will wrap DB work).
   Smallest fix: rescue a narrower set (or exclude ActiveRecord::Rollback and
   SignalException family explicitly); document that hosts must not rely on
   Guard to wrap open transactions. Deeper: only rescue a host-configured list.

2. Severity: high. Confidence: high. Location: plan rules 1 and machines;
   contrast `Store.visible?` (powered? gate).
   Why: Guard runs `parked` when power is pending or parked. Ordinary
   `visible?` is false when not ready. Two entry points diverge: boolean call
   sites hide the feature; Guard always executes business `parked`. That may be
   intended (legacy path always live) but the plan does not state it as a hard
   product invariant. Operators can read pending as off and still hit production
   code via Guard. Evidence: observed Store powered? conjunction; plan text
   "Power parked/pending, or no matching experiment => run parked". Kind:
   observed + plan text.
   Smallest fix: RFC sentence: Guard.call always may run `parked` even when
   pending; pending is not a no-op for Guard. Optionally require ready? before
   any experiment, with parked still always defined.

3. Severity: high. Confidence: medium. Location: error_rate denominator;
   Stats.record vs Guard executor.
   Why: Trip rule uses error_count/shown_count. Guard may never call visible?.
   Plan does not define when guarded delivery increments shown (experiment only,
   parked+experiment, or selection event). Wrong denominator delays or false-trips
   park!. Evidence: artifact-missing in plan; observed stats today only on
   visible?/variant. Kind: artifact-missing.
   Smallest fix: RFC: one shown increment per Guard.call when an experiment path
   is selected (not when only parked); errors only for experiment failures;
   parked-only calls do not affect error_rate. Spell the counter writes in the
   per-call machine.

4. Severity: high. Confidence: high. Location: YAML type experiment + variant
   vs Guard experiment DSL.
   Why: Two parallel experiment concepts (assignment weights vs executable
   arms). Plan keeps both for v1. Operators and hosts will conflate names,
   admin UI, and stats. Evidence: plan "Do not replace variant in v1"; RFC-0003
   experiment type. Kind: observed plan + tree.
   Smallest fix: RFC glossary and README matrix: when to use variant vs Guard;
   forbid identical arm names across both without a documented bridge; admin
   labels must differ ("variant weights" vs "delivery experiments").

5. Severity: medium. Confidence: high. Location: feature-level filters vs
   per-experiment filters.
   Why: Composition unspecified. Does selection require feature ready + feature
   audience AND experiment filters, or only experiment filters once ready?
   Ambiguity yields wrong routing and duplicated YAML. Evidence: artifact-missing.
   Smallest fix: RFC: power ready required for experiment selection; feature-level
   audience either unused for Guard (experiments carry all targeting) or AND-ed;
   pick one and test the matrix.

6. Severity: medium. Confidence: high. Location: gate cache + auto park!.
   Why: Kill switch is a gate write. Other processes may keep serving an
   experiment until cache TTL / missing cross-process invalidation (already
   documented for Onni cache). Blast radius after threshold is not instant
   fleet-wide. Evidence: observed README/cache contract; plan reuses park!.
   Kind: observed.
   Smallest fix: document kill-switch freshness bounds next to exception policy;
   recommend short cache_ttl or no cache on hosts that need fast park.

7. Severity: medium. Confidence: high. Location: hour-bucket trip window.
   Why: error totals reset each UTC hour for the trip check. A feature can
   hover under floor forever without parking, then spike. After park, hour
   reset does not ready (good), but before park the window is a silent heal.
   Evidence: plan window v1 text. Kind: observed plan.
   Smallest fix: document as intentional; or add minimum absolute floor that
   uses retained multi-hour sum; or require floor to be hit inside the hour
   with admin-visible window label.

8. Severity: medium. Confidence: medium. Location: class-declared experiment
   filters vs gates ("publish-on-load rule in RFC").
   Why: Unspecified publish creates either invisible admin (defaults only in
   Ruby) or surprising writes on boot. Evidence: artifact-missing. Kind:
   artifact-missing.
   Smallest fix: choose: (a) class filters are process-local defaults never
   written until admin/API mutates, admin shows effective merge; or (b) explicit
   `install!` / first ready copies defaults into gates once.

9. Severity: medium. Confidence: high. Location: Onni.selected / inline
   Onni.guard sugar.
   Why: selected(name, actor) needs a registry of experiments. Inline sugar has
   no named experiment and no class. Admin cannot tune per-experiment targeting
   for anonymous sugar. Evidence: plan API sketch. Kind: observed plan.
   Smallest fix: sugar creates a single reserved experiment name (e.g. :on) with
   documented gates; or selected only works with registered Guard classes;
   sugar remains local call-site only without admin experiment rows.

10. Severity: medium. Confidence: high. Location: plan Implementation phases
    (duplicate Phase 0); Phase 1 RFC bundles expires_at + Guard + stats + admin.
    Why: Duplicate phase heading; oversized first RFC increases review and revert
    cost. expires_at fail-closed removal alone breaks shown/skip for overdue
    flags (plan admits). Evidence: observed plan lines. Kind: observed.
    Smallest fix: delete duplicate Phase 0; split RFCs: (A) expires_at hygiene,
    (B) error_count + exception_limit + park, (C) Guard DSL / N experiments.

11. Severity: medium. Confidence: medium. Location: method names on Guard
    (parked, experiment names).
    Why: Experiment name colliding with Base methods (call, feature, experiment,
    parked, class, object) or Ruby keywords breaks dispatch. Evidence: inference
    from proposed DSL. Kind: inference.
    Confirm: reserved method/name list in Registry validation. Smallest fix:
    reject reserved experiment names at class load.

12. Severity: low. Confidence: high. Location: ActiveAdmin "tune any parameter".
    Why: Today RolloutForm only audience/variants; stats! and exception policy
    have no UI yet. Plan scope implies a large admin surface. Evidence: observed
    rollout_form.rb vs plan operator targeting. Kind: observed.
    Smallest fix: phase admin panels with API; do not block core executor on full
    parity.

13. Severity: low. Confidence: high. Location: swallow StandardError then run
    parked.
    Why: Masks programmer errors as rollout failures; inflates error_count;
    may park on bugs. Evidence: inference from machine. Kind: inference.
    Confirm: optional re-raise-after-record mode or only rescue named hierarchy.
    Smallest fix: document; log error class/message via instrumenter without
    actor PII; consider not counting NoMethodError toward park threshold.

### Pipeline map (proposed)

ingress: Guard.call / Onni.guard / error! / admin mutations
app logic: select experiment vs parked; rescue; trip rule
cache: gate snapshot (v4->v5); generation bust on park!
database: gate upsert; stat bucket upsert including error_count
queue/worker: none required for trip (inline park!)
egress: return value; feature_operation / stats.record notifications

Hot path inference: each Guard.call adds selection + possible error upsert +
possible park write on top of today's evaluation. Existing stats_write pressure
episode remains the budget baseline; confirm with bench after Phase 2.
Check: extend benchmarks/stats_write.rb with error_count upsert and trip park.

### Boundary and control

Commanders: host request (Guard), operator (Admin/API), auto-trip (error!).
Intended vs commanded vs reported: operator ready! can disagree with auto-park
until refresh; multi-process cache can disagree with commanded park without a
fleet alarm. Independent safety: host policy on admin actions; Guard is not
authorization (plan correct).

### Contract / lineage

Breaking: expires_at no longer fail-closes visible?/variant; overdue flags will
show and change shown_share. Publish identifier: selected path name, experiment
gate keys, error_count column, exceptions gate JSON, cache prefix v5. Mark
dependents stale: audience matrix expiry cases, store_spec expiry examples,
README, Flag expires helpers if they imply hide.

### Product surface

Admin must show power vs delivery path clearly (parked power vs parked path
method). Overdue expiry visual only. Reset errors must not look like ready!.

### Trace and identification

Prefer experiment name and feature key on events; avoid actor ids on error
payloads beyond existing mutation fields. Confirm against current
feature_operation payload allowlist.

### Modes skipped

Learned-systems: no model. Dependency-audit: no new package. Full resource bench:
no Guard bytes yet (inference only, named check above).

## Effects

Review written. Plan later updated to fold findings 1-13 into decisions,
machines, counters, glossary, phases (RFC A/B/C split), and non-goals. See
plan Effects. No product code changes.

## Next

- Draft RFC A/B/C from the updated plan; keep findings 1-5 as acceptance checks.
- Open live-work issue when implementation starts.
- Re-audit after RFC C draft.

## Source

- [Plan](../plans/20261114103806_exception-rate-park-and-error-stats.md)
- lib/onni/store.rb (visible?/expired?/powered?)
- lib/onni/settings.rb (power_state)
- app/models/onni/rollout_form.rb (admin mutation surface today)
- README cache / stats write pressure notes
- ActiveRecord::Rollback ancestor check in this session
