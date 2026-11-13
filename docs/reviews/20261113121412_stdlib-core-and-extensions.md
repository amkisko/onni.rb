# Standard-library core extraction

## Participants

Andrei Makarov (@amkisko), confirmed in this session.

## Decisions

Implement the operator's standard-library-first requirement through RFC-0004.
The [live record](../issues/20261113113242_stdlib-core-and-extensions.md) owns the
requirement and dependency fitness decision. The preceding package/boot artifact
is the frozen baseline. Keep framework implementations in the current gem with
explicit entry points instead of introducing separately versioned packages.

ActiveSupport moves from unconditional core dependency to an explicitly loaded
notification backend. ActiveRecord and Rails remain host-owned dependencies;
ActiveAdmin loads the integrations its dashboard needs. No third-party version
or Ruby pin changes. No upstream version-interval upgrade notes are applicable.
The required adaptation is removal of core helper calls, ambient framework
detection, default duration values, and automatic engine/admin setup.

## Effects

### Contract and implementation

`require "onni"` now works without any runtime gem dependency. A guarded process
rejects ActiveSupport, ActiveRecord, ActiveAdmin, and Rails requires while
exercising variant assignment, expiry, import, counters, cleanup, and errors.
An ambient fake Rails engine/logger is not invoked. Core does not expose the
admin authorization setting or build the unregistered persistence adapter.

Configuration uses integer retention seconds or nil, a relative registry path,
and optional logger/instrumenter objects. Unknown-feature and telemetry errors
use the configured logger. No ActionReporter discovery remains. Native nil/empty
checks and Time/Date operations replace the core's framework helper usage.

Onni.register_adapter registers factories in a frozen snapshot under the normal
lock and builds outside it. Memory is built in; the ActiveRecord extension
registers persistence. Reentrant factory and invalid-registration specs pass.

The ActiveRecord extension owns the three models now under lib/onni/active_record.
Their constants, tables, associations, and schema stay the same. The Rails-only
engine has no admin model/view/locales paths. The ActiveAdmin extension enables
those paths, route helpers, and the existing admin policy setting explicitly.
The old implicit engine require is removed; no compatibility loader is retained.

Core/config/adapter tests fail four examples before implementation. Extension
fixtures fail three examples before the explicit entry points exist. All now
pass. A real consumer bundle contains only onni and bundler, with no framework
loaded. The consumer also passes a boolean evaluation on Ruby 3.4.11.

### Package and resource comparison

The [evidence bundle](../../benchmarks/stdlib_core_results.json) retains exact
commands, source/probe digests, package identities, raw samples, consumer and
lockfile proofs, scan results, and validation counts. Seven alternating fresh
Ruby 4.0.2 processes per side run on arm64-darwin24 with warm filesystem caches.
Bundler setup and selected framework preloads are outside the timed region.
RSS is the native process-lifetime peak, including setup and result formatting.

- Core require median CPU: 96.201 -> 18.056 ms, -81.2%.
- Require plus first evaluation/stat write: 96.427 -> 18.898 ms, -80.4%.
  Every sample returns visibility true and shown_count 1.
- Require allocations: 42756 -> 8524. First-use allocations: 44615 -> 9293.
- Plain process peak RSS: 37175296 -> 29048832 bytes. First-use peak RSS:
  37781504 -> 29507584 bytes. These are whole-process peaks, not retained-heap
  deltas or a full Rails application startup.
- After ActiveSupport is already loaded, core require CPU is effectively
  unchanged, 7.502 -> 7.492 ms, inside the 3% noise floor.
- Equivalent Rails integration registration: 4.848 -> 5.092 ms, +0.244 ms.
  The baseline implicitly loads its engine; the new sample requires onni/rails.
- ActiveAdmin integration after framework preloading: 4.577 -> 5.562 ms,
  +0.985 ms. Its explicit registrations are a measured cost, not a speedup.

The mandatory runtime dependency closure shrinks from 14 gems and 15018003
logical installed-file bytes to zero. Ruby's provided standard libraries remain
part of the runtime and are outside that external-gem graph. Development still
uses the existing 113-gem resolved checkout graph. All four lockfiles retain
the same third-party names, versions, and platforms; only Onni's runtime edge
is removed by this episode.

Three fixed-epoch builds per side are identical. Own archive bytes grow from
44544 to 46080, +1536; raw package file contents grow 132029 -> 135984 bytes.
There are 68 delivered files instead of 64. The same archive still includes
the optional extensions and their assets. Do not call this a smaller own .gem
or claim that existing development files were removed from the machine.

The existing evaluation gate passes all six unchanged limits: CPU 1.225603s,
wall 1.225762s, allocations 4419145, peak RSS 41025536 bytes, serialized stats
664 bytes, and lib/app/sig 96987 uncompressed bytes. CPU seconds are the energy
proxy; joules, image layers, deployment network bytes, and co-location effects
were not measured. No live service was contacted by these benchmarks.

### Validation and dependency assessment

- `bundle exec rspec`: 231 examples, zero failures, seed 9563.
- `BUNDLE_GEMFILE=gemfiles/rails72.gemfile bundle exec rspec`: 231 examples,
  zero failures, seed 35551, on Ruby 4.0.2.
- `BUNDLE_GEMFILE=gemfiles/rails8ruby34.gemfile bundle exec rspec`: 231 examples,
  zero failures, seed 62302, on Ruby 4.0.2.
- `BUNDLE_GEMFILE=gemfiles/rails8ruby4.gemfile bundle exec rspec`: 231 examples,
  zero failures, seed 53220, on Ruby 4.0.2.
- `POLYRUN_COVERAGE=1 bundle exec polyrun parallel-rspec --workers 5 --merge-failures`:
  five workers pass and merge nine fresh fragments, including four isolated
  process fixtures. Tests execute behavior and contribute actual coverage.
- `bundle exec polyrun report-coverage -i coverage/merged.json -o coverage --basename stdlib-core --format json,console`:
  1288/1319 executable lines, 97.65%, across 43 files.
- `RUBOCOP_CACHE_ROOT=tmp/rubocop-cache bundle exec rubocop`: 100 files, no offenses.
- `bundle exec rbs validate`, `ruby usr/bin/check_locale_parity.rb`, and
  `git diff --check`: exit zero. Locale parity covers en, two keys.
- `ruby usr/bin/check_loc.rb`: exit zero; existing large-file warnings are
  app/admin/features.rb, 212 lines, and lib/onni.rb, now 162 lines.

The current advisory database is revision 4d71b123428e33f694e805ce15351ee3d8d62ef7,
dated 2026-11-11. Required scans pass the root, both Rails 8 locks, and the minimal
core consumer lock. The unchanged Rails 7.2 test graph has 18 matches and remains
under investigation in the [dependency record](../dependencies/20261113120312_rails72-advisory-matches.md).
No deployment exploit or blanket security clearance is claimed.

Pipeline: package -> require -> explicit plugin registration -> adapter ->
evaluation/counters -> host view. Core cache authority and invalidation are
unchanged; its inputs still rebuild from the configured registry and adapter.
No queue, device, or physical-control path is introduced. Logs/notifications
are explicit configured destinations; fixtures emit no new person identifier.
Host access policy and deployed collectors remain outside this local episode.

Person-facing surface: ActiveAdmin Flags, history, and storage summary. Model
loading and retention representation change internally; layout, controls, and
displayed day counts stay the same. Request specs exercise the rendered pages.
No new screen or layout needs a screenshot; narrow/keyboard/visual states were
not re-assessed. There is no learned-system surface in this change.

## Next

The standard-library extraction is complete. Existing hosts must select their
extension and persistent adapter and convert duration retention to seconds.
The separate Rails 7.2 advisory assessment remains open. A full Ruby 3.4 Rails
suite, deployed-host policy review, and cold-disk measurements are not claimed.

## Source

- [RFC-0004](../../rfcs/0004-stdlib-core-and-opt-in-extensions.md)
- [Live work](../issues/20261113113242_stdlib-core-and-extensions.md)
- [Raw measurements](../../benchmarks/stdlib_core_results.json)
- [Engineering change note](../changelogs/20261113121412_stdlib-core-and-explicit-extensions.md)
- [Consumer instructions](../../README.md)
