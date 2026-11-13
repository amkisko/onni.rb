# Standard-library core and explicit extensions

## Participants

Andrei Makarov (@amkisko), confirmed earlier in this session.

## Decisions

Implement RFC-0004 in response to the operator's standard-library-first direction.
The core must declare zero runtime gem dependencies and run without framework
helpers. Keep optional integrations in the current distribution with explicit
ActiveSupport, ActiveRecord, Rails, and ActiveAdmin entry points. No new registry
package or framework replacement is needed.

Dependency fitness: ActiveSupport's unconditional runtime edge conflicts with
the named requirement. Move vendor-specific operations to extensions; replace
only the core's nil/empty checks and elapsed-time calculations with Ruby APIs.
No package version is upgraded. Upstream version-interval release-note mapping
does not apply; used surfaces and required adaptations are captured by RFC-0004
and the targeted specs. Development/framework packages retain their existing pins.

Retain the preceding package/boot episode as the frozen baseline. Compare the
same compressed artifact, consumer install graph, boot CPU/RSS, and first usable
evaluation using seven alternating process samples. Existing evaluation resource
ceilings remain unchanged. Run advisory checks on every lockfile after resolution.

## Effects

Feasibility: an empty consumer Gemfile resolves locally with no dependencies;
requiring json, yaml, and date succeeds under that isolated bundle on Ruby 4.0.2.
The local Polyrun gemspec also declares zero runtime gem dependencies.

The first core/config/adapter specs reported four failures before implementation;
the three extension process fixtures also failed before their entry points existed.
The retained implementation now passes the core and explicit framework contracts.
The isolated consumer resolves only Onni and Bundler and also evaluates a flag on
Ruby 3.4.11. Third-party node versions remain unchanged in all four lockfiles.

Before/after measurements, package identities, consumer proof, and final validation
live in the linked evidence and completed review. The advisory scan succeeds for
the root and both Rails 8 graphs; the existing Rails 7.2 fixture has 18 matches,
tracked in its own dependency record without a claim of downstream exploitation.

## Next

The core extraction is complete. The separate Rails 7.2 dependency assessment
remains open; do not treat that fixture as a security-approved host baseline.

## Source

- [RFC-0004](../../rfcs/0004-stdlib-core-and-opt-in-extensions.md)
- [Frozen before measurements](../../benchmarks/package_boot_results.json)
- [Completed review](../reviews/20261113121412_stdlib-core-and-extensions.md)
- [Raw evidence](../../benchmarks/stdlib_core_results.json)
- [Rails 7.2 assessment](../dependencies/20261113120312_rails72-advisory-matches.md)
