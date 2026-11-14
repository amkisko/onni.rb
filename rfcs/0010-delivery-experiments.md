# RFC 0010: Delivery experiments

- Type: Standards Track
- Status: Experimental
- Created: 2026-11-14
- Author: Codex

## Summary

Add Onni::Delivery with reserved parked path and ordered executable
experiments, plus Onni.deliver for one inline experiment.

## Motivation

Implement the delivery and operator workflow agreed in the
[delivery plan](../docs/plans/20261114103806_exception-rate-park-and-error-stats.md).

## Guide-level explanation

Subclass Onni::Delivery, declare feature and experiment entries, and implement
parked plus the named experiment methods. Call the class with an actor and the
method arguments. Pending power runs the existing path; ready power permits the
first matching experiment. See README.md for a complete checkout example.

## Reference-level explanation

feature :name, **settings owns a Ruby catalogue entry with define! validation.
Bare feature :name binds an existing entry. Each name has one catalogue owner;
repeated define! may replace its own definition but cannot replace a Delivery
owner. Ruby is preferred; YAML input remains compatibility (RFC-0007 revised).
experiment :name, **filters optionally accepts a method body block. Methods
receive positional arguments, keyword arguments and the caller block. parked
is implemented as a method or parked block. Zero experiments is valid.
Reject invalid/reserved/Ruby-keyword/host-method collisions at declaration.
Names overlapping variant arms on the same feature are rejected in either
mutation direction. Defaults never write gates on class load. Optional catalogue delivery_experiments
maps declared arm names to validated targeting defaults, including compatibility
YAML input. Merge class defaults, then catalogue targeting, then runtime targeting
per field. Unknown catalogue arms fail before execution.
call(actor = nil, *arguments, **keywords) returns the chosen path's value.
selected(name, actor = nil) inspects selection without executing or counting.
Unknown feature or missing executable body raises before any path runs.
Pending/parked power always runs parked. Ready selects the first matching
experiment. Only per-experiment filters participate, using audience AND rules
and an explicit opener. Feature filters and conditions apply only to boolean
and variant evaluation. No match runs parked. Expiry never controls routing.
experiment_filters!(name, experiment, **filters) applies per-field overrides;
nil removes a clause. Clearing runtime overrides restores class defaults.
Onni.deliver(name, actor = nil, parked:, &experiment) uses the same executor
and reserved :on experiment (default everyone: true); it binds a process-local
inline entry so selected and runtime targeting can find it. A class binding
and inline binding cannot share a name.
Only experiment StandardError failures fall back to parked. ActiveRecord::Rollback
and non-StandardError exceptions propagate. Selection/configuration failures,
observe failures and parked failures propagate. This is not transaction recovery;
hosts must arrange rollback themselves before invoking fallback.
Default rescue_policy(signal: :exception, count_programming_errors: false)
counts rescued failures except NameError/NoMethodError. Hosts may configure
that policy on their Delivery class. Exception instrumentation contains feature,
experiment and error_class, never actor, arguments, message or backtrace.
Raw exception messages may contain credentials and are therefore omitted.
Delivery does not create shown/skip counts; variant only assigns names/weights.
Registered classes must load in every process. Registry reload preserves Ruby
catalogue entries. Constant reload ownership uses stable named-class identity.

## Drawbacks

Hosts must load Ruby catalogue definitions in each evaluating process and review
changed contracts before deployment. Serialized writes bound throughput on a
single hot feature. Cached reads are not a fleet-wide instant stop mechanism.

## Rationale and alternatives

Reuse the existing power machine and adapter gates. Keep ordinary boolean flags
and assignment-only variants available. Avoid an additional power state or
unbounded analytics storage.

## Prior art

Existing Onni power, targeting, stats and programmatic-definition contracts in
RFC-0003, RFC-0005, RFC-0006 and RFC-0007.

## Unresolved questions

No unresolved implementation choices. Maintainers still review the experimental
contract before release.
