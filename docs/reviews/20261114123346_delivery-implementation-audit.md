# Delivery implementation engineering audit

## Participants

Andrei Makarov.

## Decisions

Review the implementation of RFC-0008 through RFC-0011 against the source plan.
Iterate through failing specs, repairs and pressure proves. Optional weighted
selection and per-experiment power remain outside this implementation. Keep the
working tree reviewable; no release or publication was requested.

Run contract, lineage, resource/budget, performance, trace/identification,
privacy, product-surface, security and boundary/control modes. The host owns
policy and arbitrary business IO. Onni owns power, targeting and integer levels.
Skip learned systems (no model), cloud deployment, native application interfaces,
identity protocols and remote messaging (no new such product surface). No
package/runtime/lockfile changes require a dependency audit. The encountered
CSV failure was our undeclared consumer require, not an upstream package defect.

## Effects

All 13 observed implementation findings are resolved. The machine-readable
finding list includes severity, confidence, pipeline stage, location, evidence,
smallest fix and before/after indicators. High-confidence findings were repaired
before accepting the final gates. It includes the deterministic binding race
(8 competing bindings before, 1 after), rollback notifications (2 false successes
before, none after), preload regression (51 queries before, 1 after), level-map
cardinality, malformed reset/policies, naming collisions, CSV packaging,
configured inline arms and accessible field descriptions.

### Pipeline and control

1. Ingress: Ruby calls or host-authorized ActiveAdmin commands validate inputs.
2. Selection: ready power and the first matching experiment audience choose one
   executable path. Pending/parked/no-match run parked. Boolean/variant contracts
   remain separate. Metadata expiry does not gate execution.
3. Experiment failure: exclude rollback and exit exceptions. Emit only feature,
   experiment and error_class; optional signal observation follows the policy.
4. Durable write: update level and threshold park inside one adapter lock or
   transaction. The expensive unit is a serialized per-feature gate replacement,
   not a read of every statistical bucket. Work is bounded by declared signals
   and current feature gates. No retry loop masks races.
5. Effects: publish mutation success after commit. Rollback suppresses events.
   Requests can reuse preloads only within the same transaction/adapter context.
   Shared cache entries derive from adapter gates, use prefix v5, and may lag
   other processes until TTL/request refresh. Clearing process/local caches
   rebuilds from ActiveRecord gates; memory-adapter reset loses ephemeral state.
6. Egress: return exactly one result, propagate parked/selection/observation
   failures, and keep ordinary shown/skip counters separate from signal math.

The host policy rejects unauthorized admin mutation with 403 and no state
change. Submitted experiment names select only registered arms. Malformed
thresholds produce 422 with the form and submitted value retained. Exports are
maintainer output and can contain declared audience identifiers; README states
that distribution belongs to the host. There is no added actor/device identity,
exception message, argument or backtrace in Delivery error events. A runtime
subscriber assertion verifies the exact three-field error payload. Existing
actor-targeting mutations retain their existing identity-bearing contract.

### Pressure and resource evidence

Calibrated before baseline. Four distinct stage fixtures measured 11/23/37/53 us;
a direct stage-versus-wall comparison passed. Memory is process_lifetime peak
RSS from an isolated child, not a claimed stage measurement. CPU milliseconds
are the energy proxy; network is not_in_scope for these local-only fixtures.
The first attempted native-memory helper was unavailable under the declared
bundle. No baseline was accepted from that attempt; the final harness uses the
host time command and fails closed when its meter is blocked.

Raised WRITERS from 1 to 8 at OPS=100, with 3 samples per load. Ran 12 audit and
pressure cycles, retaining every failed prove. Final five noise samples informed
the explicit latency allow-raise decision. Tightened wall/CPU, fixture retained
bytes and shipped-source ceilings; no speed or whole-product memory reduction
is claimed from the partial-implementation baseline. The last first-party
optimization removed redundant default copies/power scans. Final memory and
durable gates passed all series on the same source hash.

Memory pressure max across 3 final samples: wall 29.437 ms,
CPU 29.507 ms, peak RSS 32260096 bytes, retained gate fixture
89 bytes. Each sample executed 800 loops and retained all
1600 signal increments, with zero write/level errors.

Durable SQLite pressure max across 3 final samples: wall 1351.093 ms,
CPU 1348.689 ms, peak RSS 74776576 bytes, SQLite/WAL fixture
4214288 bytes. There were zero write/level errors. A separate
8-process probe repeated 800 increments in three fresh databases: every final
level was 800, with exactly one committed automatic park event and no errors.

Uncompressed lib/app/sig bytes: 143786. The local compressed
gem built successfully at 62976 bytes. The gem was not published. Raw
reports identify base revision, working-tree state, source/probe hashes and
start/end timestamps; the process probe matches the final source hash.

### Product surface

Assessed the running test app at onni.rails.fi on a 1440px desktop and an actual
390px emulated viewport. The first preview placed signal controls below long
audience forms; the revised hierarchy shows power/expiry, signals/count policy,
then expandable Delivery audiences and ordinary visibility targeting. Native
summary controls opened with the Space key. At 390px, document width and scroll
width were both 390 and measured elements did not overflow. Screenshots are
linked below. Request tests verify empty counts, successful mutations, denied
access and invalid input, plus unique description ids and their references.
There is no async loading state in these server-rendered forms.

The operator can set a threshold, reset its level while remaining parked, and
edit an experiment audience. Runtime state and the parked path have separate
labels. A person still needs to assess screen-reader speech and theme contrast;
this was not a full accessibility certification. Browser and preview processes
used only disposable fixtures and were stopped after inspection.

### Exact validation commands and observed results

- POLYRUN_COVERAGE=1 BUNDLE_IGNORE_CONFIG=1 bundle exec rspec
  -> 494 examples, 0 failures; 95.73 percent lines (1885/1969), 59 files.
- BUNDLE_IGNORE_CONFIG=1 bundle exec rspec spec/onni/delivery_spec.rb
  -> 12 examples, 0 failures after adding the exact error-payload assertion.
- BUNDLE_IGNORE_CONFIG=1 bundle exec rubocop --cache false --format simple
  -> 133 files inspected, no offenses (final output recorded after repairs).
- BUNDLE_IGNORE_CONFIG=1 bundle exec rbs validate
  -> exit 0.
- ruby usr/bin/check_locale_parity.rb
  -> Locale parity ok: en, 2 keys.
- ruby usr/bin/check_loc.rb
  -> exit 0; warnings on app/admin/features.rb, lib/onni.rb and the unchanged
     usr/lib/release_version_check.rb, all below the 300-line failure ceiling.
- BUNDLE_IGNORE_CONFIG=1 bundle exec ruby usr/scripts/build_admin_assets.rb
  -> stylesheet built successfully; no dependency install was needed.
- BUNDLE_IGNORE_CONFIG=1 bundle exec rake -T onni
  -> onni:export and onni:export_yaml/json/csv listed.
- BUNDLE_IGNORE_CONFIG=1 bundle exec ruby benchmarks/delivery_pressure.rb --calibrate
  -> calibration passed (ephemeral sample under benchmarks/output/).
- BUNDLE_IGNORE_CONFIG=1 CEILINGS=benchmarks/delivery_ceilings.json bundle exec ruby benchmarks/delivery_pressure.rb
  -> 3 final memory samples, failed series empty, zero write/level errors.
- BUNDLE_IGNORE_CONFIG=1 ADAPTER=active_record CEILINGS=benchmarks/delivery_active_record_ceilings.json bundle exec ruby benchmarks/delivery_pressure.rb
  -> 3 final durable samples, failed series empty, zero write/level errors.
- BUNDLE_IGNORE_CONFIG=1 bundle exec ruby benchmarks/delivery_processes.rb
  -> 3 samples; 800/800 retained increments, 1 park event, 0 errors each.
- BUNDLE_IGNORE_CONFIG=1 bundle exec gem build onni.gemspec --output tmp/onni-delivery.gem
  -> local gem built successfully.
- git diff --check
  -> exit 0.

The earlier full run exposed four stale expiry/UI expectations, subsequently
updated to the new contract. Failed pressure gates remain in raw reports rather
than being replaced by successful samples. The minimal consumer Gemfile first
reproduced CSV LoadError; it then exported successfully without declaring csv.
No spec/README.md exists in this checkout; existing executable specs and the
project test/coverage commands supplied the local test conventions.

## Next

No implementation finding remains open in the audited scope. Cut recorded as
3.0.0; deliver with `make release`. PostgreSQL, real shared-cache backends,
long-duration retention, assistive technology and host-specific business
callbacks need their own environment-specific checks; these local fixtures do
not establish them.

## Source

- [Live work](../issues/20261114113817_delivery-signals-and-catalogue.md)
- [Plan](../plans/20261114103806_exception-rate-park-and-error-stats.md)
- [Finding records](../../benchmarks/delivery_audit_findings.json)
- [Pressure binding](../../benchmarks/delivery_binding.md)
- [Iteration log](../../benchmarks/delivery_iterations.json)
- [Final memory gate](../../benchmarks/delivery_final_gate.json)
- [Final durable gate](../../benchmarks/delivery_active_record_gate.json)
- [Process probe](../../benchmarks/delivery_process_results.json)
- [Desktop preview](../assets/delivery-desktop.png)
- [Narrow preview](../assets/delivery-narrow.png)
- [Engineering changelog](../changelogs/20261114122926_delivery-signals-and-catalogue.md)
