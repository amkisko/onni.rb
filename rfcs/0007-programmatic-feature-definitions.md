# RFC 0007: Programmatic feature definitions

- Type: Standards Track
- Status: Draft
- Created: 2026-11-13
- Author: Andrei Makarov
- Relates: RFC-0005, RFC-0006

## Summary

Provide define! as an explicit programmatic registry entry point while keeping
features.yml the recommended shared catalogue.

## Motivation

Applications occasionally need a flag before a YAML definition can be deployed.
An official validated API avoids private registry mutations while retaining
unknown-name strictness and documented ownership of feature intent.

## Guide-level explanation

Prefer features.yml: the team can review feature intent, description, and
expiration together with application code. Runtime definitions are an exception,
not a recommended replacement for that shared record.

define!(name, description:, expires_at:, **settings) registers a process-local
feature. Description must be a nonblank string and expiration a nonblank,
parseable timestamp string. Audience, variants, and statistics use the same
validated definition fields as YAML. Definition alone leaves a new flag pending;
stored power and runtime overrides still apply when the name already has rows.

Calling define! again replaces that programmatic definition and requires the
metadata again. Stored runtime gates and historical counters are retained. A
YAML-owned name cannot be shadowed. Unknown visible? remains false, unknown
variant remains nil, and other unknown mutations still raise KeyError.

## Reference-level explanation

Definition registration validates and copies caller data before publishing a
complete definition under the registry lock. Readers see the previous or next
definition. Expiration parsing uses the same timestamp interpretation as YAML;
the cached parsed deadline is rebuilt from the supplied expiration.

Registry.reload! reloads YAML and retains programmatic definitions. A YAML name
colliding with a programmatic name fails explicitly. To move a runtime feature
into YAML, deploy its YAML definition with a process restart. Runtime definitions
disappear when the process exits and must be defined in every evaluating worker.
The adapter persists gates and counters, not programmatic definitions. Adapter
or application cache resets do not remove the in-process definition.

The host owns any durable source used to recreate these definitions. Define
them during shared application initialization when every worker needs them.
Definition changes apply to subsequent evaluations; existing Flag objects remain
metadata snapshots. Do not add an automatic define-on-miss path or infer intent
from stored gates. No new database schema is required.

## Drawbacks

Process-local registration does not broadcast across workers or survive restart.
The host must arrange consistent initialization, or use the recommended YAML
catalogue. Reusing an existing feature name retains its stored runtime settings.

## Rationale and alternatives

Keep documentation metadata mandatory at this entry point. Avoid making a
missing name an implicit declaration. A durable database definition registry
would require another ownership and deployment contract and is deferred.

## Prior art

Registry validation already owns feature defaults, and register_group provides
an explicit in-process registration pattern. Gate storage is separate from the
definition catalogue.

## Unresolved questions

Maintainer review and release selection remain. Durable distributed definition
management is outside this contract.
