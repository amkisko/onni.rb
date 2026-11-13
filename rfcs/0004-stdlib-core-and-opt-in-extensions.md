# RFC 0004: Standard-library core and opt-in extensions

- Type: Standards Track
- Status: Experimental
- Created: 2026-11-13
- Author: Codex
- Relates: RFC-0003

## Summary

Make Onni's core use Ruby's standard library with no runtime gem dependencies.
Load framework integrations only through explicit extension entry points.

## Motivation

The preceding package/boot measurements show that ActiveSupport introduces a
runtime installation graph even for a standalone memory-backed caller. Deferring
optional classes does not remove this dependency or the framework helpers in core.

## Guide-level explanation

`require "onni"` provides typed flags, the memory adapter, groups, variants,
configuration, statistics, and imports. It does not discover or initialize a
framework already present in the process.

Hosts opt in with `require "onni/active_support"` for notification delivery,
`require "onni/active_record"` for persistence, `require "onni/rails"` for the
Rails engine and request lifecycle, and `require "onni/active_admin"` for the
dashboard. Hosts install the external gems those extensions require. Extensions
stay in the same distribution; no new independently published package is needed.

Core time windows and retention are elapsed seconds. The default retention is
7776000 seconds. A host using Rails duration helpers converts them with `to_i`.
`features_path` defaults to `config/features.yml` relative to the working directory;
the Rails extension supplies the application-root path during initialization.

## Reference-level explanation

- The gemspec declares zero runtime dependencies. Development tooling remains
  development-only. No core load path requires ActiveSupport or checks for Rails,
  ActiveRecord, ActiveAdmin, or ActionReporter to change behavior implicitly.
- Core predicates use Ruby nil/empty checks. Time windows use Time.now, elapsed
  seconds, UTC hour buckets, and Date for calendar presentation.
- `stats_retention` accepts a nonnegative Integer of seconds or nil. Nil requires
  an explicit purge cutoff. Invalid values raise ArgumentError before assignment.
- `configuration.logger` is an optional logger-compatible object. Core reports
  failures through it without discovering a framework logger or reporter.
- `configuration.instrumenter` is an optional object with `instrument(name,
  payload) { |payload| ... }`. Core keeps event names and fields. With no backend,
  it yields the payload directly. The ActiveSupport extension installs Notifications.
- `Onni.register_adapter(name) { adapter }` registers a factory. The memory factory
  is built in; the ActiveRecord extension registers `:active_record`. Unknown
  names raise ArgumentError. Factories run outside the registration lock.
- The ActiveRecord extension owns its adapter and model loading. The Rails
  engine does not auto-select persistence or load admin models/views. Host
  configuration selects the adapter explicitly.
- The ActiveAdmin extension enables admin paths, locales, route helpers, and the
  existing admin policy setting. It explicitly loads the Rails and persistence
  extensions it needs. Core has no admin authorization setting.
- Existing rollout, sampling, additive counts, cache adapter interface, event
  payload fields, and database schema remain in place. Onni remains an experiment
  and rollout tool, not application authorization.
- There is no implicit engine loading or legacy fallback for Rails duration
  retention values. Hosts must load the intended extension and pass seconds.

## Drawbacks

Existing Rails hosts must add explicit require entries and convert retention
configuration to seconds. Plugin dependencies are installed by the host rather
than pulled into every core consumer. Core retention measures elapsed time;
it does not implement calendar-day arithmetic across daylight-saving changes.

## Rationale and alternatives

Ruby already supplies the string, date, clock, collection, logging interface,
and configuration primitives the core needs. Replacing ActiveSupport with
another helper gem would not meet the requirement. Keeping ambient framework
detection would make behavior depend on unrelated require order.

Separate extension gems would introduce additional manifests, versions, and
release coordination for one repository and consumer contract. Explicit entry
points establish the boundary without that overhead.

## Prior art

The operator identifies Polyrun's zero-runtime-dependency core as the intended
direction. Its locally inspected gemspec and optional integration requires inform
the dependency boundary, not a requirement to copy its implementation.

## Unresolved questions

None blocks this implementation. Separate published extension packages can be
considered if their consumers or release cadence later require that boundary.
