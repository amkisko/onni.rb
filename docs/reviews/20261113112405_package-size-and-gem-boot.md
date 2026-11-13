# Package size and gem boot

## Participants

Andrei Makarov (@amkisko), confirmed in this session.

## Decisions

The [live record](../issues/20261113111148_package-size-and-gem-boot.md) owns the
scope, budgets, and optimization admission rules. Measure the existing local
1.0.0 package, including the preceding adapter repairs and concurrent release
preparation. This is a local build measurement, not a publication event.

Separate compressed distribution bytes, raw file contents, installed dependency
trees, require-only CPU, and require plus a first usable evaluation. Use native
Ruby autoload for optional implementations when measurements justify it.
Keep the dependency graph and the public API intact.

## Effects

### Repairs and retained optimization

1. Severity medium; confidence high; evidence observed; category correctness;
   location lib/onni.rb and Actor.variant_for/Flag.expires_full; stage boot -> API.
   Requiring only onni left blank? unavailable. A standalone variant call raised
   NoMethodError; the normal spec helper had hidden this by loading the extension.
   Smallest fix: explicitly require active_support/core_ext/object/blank.
   `bundle exec rspec spec/onni/standalone_boot_spec.rb` fails before repair and
   passes afterward. The isolated child also exercises expiry and import.
2. Severity low; confidence high; evidence observed; category startup work;
   location lib/onni.rb; stage require -> optional implementations.
   Every require parsed both adapters, their helpers, and both importer classes.
   Smallest fix: autoload the four existing public constants. The final probe
   loads six fewer files until a caller asks for an adapter or import operation.
   Existing adapter/import specs and the extracted-package smoke still pass.

The blank-extension repair alone changes median require CPU by -0.25%, inside
the 3% noise floor, with 132 additional allocations and zero compressed bytes.
Its purpose is correctness. Optional-loading comparisons use this corrected
version as baseline so that the optimization has a separate measured effect.

### Own gem and installed graph

Three fixed-epoch builds per variant have identical digests. Both the initial
and final .gem archives are 44544 bytes, 43.5 KiB. Raw file contents grow from
131867 to 132029 bytes across 64 files, a 162-byte correctness/loading change.
The final package matches the promoted candidate byte for byte.

The final data.tar.gz member is 39212 compressed bytes and 180224 bytes of tar
data after decompression. Raw file bytes exclude tar headers and padding.
Root documentation/metadata occupies 36042 raw bytes, app 21994, config 181,
lib 64566, and signatures 9246. No unused browser bundle was found in this
package inventory. README and signatures are useful delivered material.

Reject the coverage-config pruning candidate: removing the 105-byte file
changes raw payload and archive digests but saves zero .gem archive bytes.
The compressed package is already below the proposed 64 KiB local budget.

The resolved runtime closure contains 14 dependency gems, excluding Onni, with
15018003 logical installed-file bytes. The checkout's full resolved graph has
113 gems excluding Onni and occupies 87109748 logical bytes. These counts include
native extensions and installed documentation, and exclude registry caches,
Ruby itself, and deployment-image layers. They describe this arm64 installation.

Prism accounts for 10411843 of those runtime-dependency bytes. The observed edge
is ActiveSupport -> Minitest -> Prism; neither Minitest nor Prism loads during
the plain Onni require fixture. The checkout also has Prism edges from irb,
rbs, rdoc, and rubocop-ast. Changing one constraint would not prove a smaller
host application. No dependency constraint or lockfile was altered in this
episode, and no advisory/freshness audit is claimed by this size inventory.

### Boot proof

Use seven alternating fresh processes per side, warm filesystem caches, Ruby
4.0.2 on arm64-darwin24. Bundler setup and selected host preloading happen before
the measured region. Native RSS is a process-lifetime maximum, including host
setup and reporting. This is not a cold-disk or full Rails application boot.

Independent final median CPU readings, corrected baseline -> retained version:

- Plain require: 102.797 -> 102.326 ms, within noise; allocations 43504 -> 42757.
- Require plus first boolean evaluation/stat write: 105.523 -> 105.024 ms,
  within noise; allocations 45029 -> 44615. Every sample returns true and count 1.
- ActiveSupport/time/blank already loaded: 10.108 -> 8.820 ms, -12.7%;
  allocations 4282 -> 3535, -17.4%; newly loaded files 35 -> 29.
- Rails dependencies already loaded: 6.541 -> 5.728 ms, -12.4%; allocations
  3510 -> 2772, -21.0%; newly loaded files 31 -> 25.

The earlier trial independently observed -13.9% and -18.0% CPU on the two host
surfaces. Standalone changes stay inside the noise floor in both runs. Do not
describe the retained change as a faster complete standalone application boot.

Final process peak RSS is 37044224 bytes for plain require, 37699584 with first
evaluation, 37879808 with ActiveSupport preloaded, and 87703552 with Rails
preloaded. Every local RSS/CPU/package budget passes. No memory-saving claim is
made. Empty-control median CPU is 3 microseconds, below the observed savings.
CPU seconds are an energy proxy; joules and co-location effects are unmeasured.

The final package's existing seven-path evaluation gate also passes all six
unchanged limits: CPU 1.400969s, wall 1.403018s, allocations 4489001, peak RSS
41254912 bytes, stats payload 664 bytes, and uncompressed lib/app/sig 95806 bytes.
The extracted-package smoke proves boolean evaluation, variant assignment,
expiry formatting, import, and construction of the optional ActiveRecord adapter.

### Validation and audit scope

The [evidence bundle](../../benchmarks/package_boot_results.json) contains exact
comparison/build commands, source/probe digests, raw samples, archive members,
installed graph sizes, the package smoke, and machine-checked admission budgets.
Snapshots and extracted local gems remain under tmp/package-boot, outside git.

- `bundle exec rspec`: 222 examples, zero failures, seed 11805.
- `bundle exec rspec spec/onni/standalone_boot_spec.rb spec/onni/migrator_importer_spec.rb spec/requests/active_record_adapter_spec.rb spec/onni/engine_spec.rb`:
  23 examples, zero failures.
- `POLYRUN_COVERAGE=1 bundle exec polyrun parallel-rspec --workers 5 --merge-failures`:
  five workers exit zero, merging five worker fragments and one standalone child
  fragment. The child records real executable coverage, not source-text checks.
- `bundle exec polyrun report-coverage -i coverage/merged.json -o coverage --basename package-boot --format json,console`:
  1245/1275 executable lines, 97.65%, across 39 files.
- `RUBOCOP_CACHE_ROOT=tmp/rubocop-cache bundle exec rubocop`: 93 files, no offenses.
- `bundle exec rbs validate` and `git diff --check`: exit zero.
- `ruby usr/bin/check_locale_parity.rb`: en, two keys, pass.
- `ruby usr/bin/check_loc.rb`: exit zero; 212/169-line warnings remain for
  app/admin/features.rb and lib/onni.rb. No counter-only file split was added.

Pipeline: manifest -> deterministic package -> extraction -> Ruby require ->
optional host engine registration -> first adapter call. There is no remote
fetch, worker, physical control, cache change, or new person-facing surface in
this work. No new visual assessment is needed for these library changes.
Definitions and actor identifiers are fixtures; the measurements emit only
counts, package/source digests, version names, and schema-level outcomes. No new
tracking identifier or outbound telemetry was introduced. Host subscriptions,
deployed logs, network traces, access policy, and the CI runtime matrix were not
re-audited in this episode. Security and learned-system modes do not add a new
surface here; the earlier contract/cache/security review remains a separate run.

## Next

The package/load episode is complete. A future dependency-size change must use
an isolated host Gemfile/lockfile pair, compare the entire closure and installed
bytes, and prove compatibility before proposing a version constraint. Current
measurements do not justify removing useful shipped docs or rewriting time APIs.

## Source

- [Scope and budgets](../issues/20261113111148_package-size-and-gem-boot.md)
- [Raw measurements and commands](../../benchmarks/package_boot_results.json)
- [Package meter](../../benchmarks/package_footprint.rb)
- [Boot meter](../../benchmarks/boot_probe.rb)
- [Standalone regression](../../spec/onni/standalone_boot_spec.rb)
