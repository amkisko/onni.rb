# Package size and gem boot

## Participants

Andrei Makarov (@amkisko), confirmed earlier in this session.

## Decisions

Measure compressed .gem bytes, archive member bytes, extracted payload bytes,
and the resolved runtime dependency installation separately from the checkout's
development bundle. Build three times with a fixed SOURCE_DATE_EPOCH and compare
digests. Use extracted package contents for boot samples.

Boot probes cover a fresh Ruby process, require plus a usable first evaluation,
and the incremental require after ActiveSupport or Rails has been loaded.
Each comparison uses seven alternating child processes per side. Filesystem
caches are warm; the Ruby process and loaded-feature set are fresh. Measure
CPU, wall time, allocations, loaded files, and native process-lifetime peak RSS.
CPU seconds are the energy proxy. No registry download or remote target is used.

Proposed diagnostic ceilings, fixed before final comparisons: compressed own
package <= 65536 bytes; unpacked file contents <= 163840 bytes; median standalone
require CPU <= 0.2s; require plus first evaluation <= 0.25s; incremental require
after ActiveSupport or Rails <= 0.015s. Standalone process peak RSS <= 50331648
bytes; Rails-host process peak RSS <= 125829120 bytes. These are local episode
budgets, not deployment guarantees.

Retain a performance candidate only with >= 5% median CPU improvement on a named
boot surface and <= 5% CPU regression on the first usable standalone evaluation.
Permit at most 512 extra compressed package bytes for a measured boot benefit.
A packaging-only change must save at least 512 compressed bytes. Keep runtime
dependency declarations and published API behavior intact.

## Effects

The initial plain-Ruby smoke fails with NoMethodError on Hash#blank? when
requesting a variant. The normal spec helper loads that extension and hid the
missing dependency require. `bundle exec rspec spec/onni/standalone_boot_spec.rb`
fails one example before the explicit extension require; standalone, actor, and
flag checks then pass 16 examples. The standalone child contributes a real
coverage fragment when coverage measurement is enabled.

The initial package contains 64 files, 131867 uncompressed file-content bytes,
and 44544 compressed archive bytes. Three fixed-epoch builds are identical.
Candidate trials are isolated copies: lazy optional adapters/importer, and
excluding the coverage-tool configuration from the distributed payload.

The optional-loading candidate passed the admission conditions and was retained.
The coverage-configuration removal saved zero compressed bytes and was rejected.
An independent seven-pair proof confirms the host-preloaded loading benefit.
The final extracted package passes the existing evaluation resource gate and
the public API smoke. Findings and raw measurements live in the linked review.

## Next

This episode is complete. A smaller dependency installation would need a
separate, host-specific graph comparison and compatibility assessment. No package
constraint was changed merely to remove a transitive dependency from this graph.

## Source

- [Package meter](../../benchmarks/package_footprint.rb)
- [Boot meter](../../benchmarks/boot_probe.rb)
- [Standalone regression](../../spec/onni/standalone_boot_spec.rb)
- [Completed review](../reviews/20261113112405_package-size-and-gem-boot.md)
- [Raw evidence](../../benchmarks/package_boot_results.json)
