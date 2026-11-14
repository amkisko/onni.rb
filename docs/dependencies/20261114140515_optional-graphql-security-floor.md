# Optional GraphQL security floor

## Participants

Andrei Makarov.

## Dependency

Target: the new optional operator API and its development/test graphs.
activeadmin-graphql 0.4.1 and activeadmin-device_authorization 0.2.0 are new direct
development dependencies. graphql is promoted to a direct development dependency
with >= 2.6.15, < 3; fiber-storage 1.0.1 is the new transitive package. The normal
Onni core still declares zero runtime dependencies. Hosts install optional gems.

## Symptom

An intermediate local-only resolution selected cached graphql 2.6.10. The first
advisory scan matched four GraphQL advisories. This was not a package present in
the pre-task Onni graph or evidence of a production incident. Upstream 2.6.15
release notes list additional security fixes, so 2.6.14 was not retained as the
final optional minimum.

## Evidence

Verified published gem SHA-256 values against RubyGems metadata before loading.
The executable peer-package sources match the inspected sibling repositories.
All four new package checksums are recorded in root and appraisal lockfiles.

Upstream impact map, relative to the initially cached 2.6.10:

- 2.6.11: loaded-object type checking; this API uses no loads: argument hook.
- 2.6.12: authorization fix for the next executor; profile/input fixes touch
  visibility/coercion used by this namespace. Tests cover scope separation.
- 2.6.13: validation and execution fixes; no new optional executor is adopted.
- 2.6.14: authorization rendering fixes and complexity handling; host-policy
  denials and query bounds are explicit acceptance tests.
- 2.6.15: parser, analysis, complexity and next-executor fixes. This API accepts
  caller GraphQL documents, so the final loader and manifest floor is 2.6.15.

Classification: adapt-needed, completed for the Onni optional API. Must-adapt:
use the corrected minimum, preserve authorization boundaries and verify typed
coercion. Do-not-adopt: alternate execution engines, loads:, subscriptions,
ActionCable and unrelated client-facing resource APIs.

Assessment status: fixed for the scanned new GraphQL target at 2.6.15. No exploit
was demonstrated on the intermediate fixture. Root and both Rails 8 lockfiles
scan without matches using advisory DB revision
305f8b079a23bf95d00c881842f366bb8db19f35. This is a scoped package/advisory result,
not a claim of repository-wide security or safety for unnamed host services.

The Rails 7.2 variant retains its 18 pre-existing framework matches. Their
assessment and unresolved decision have one home in the linked Rails 7.2 note;
this task neither removes that compatibility line nor declares it safe.

## Suggested fix

Require graphql >= 2.6.15 in hosts loading onni/active_admin_graphql and update
those hosts' lockfiles. Configure real host bearer validation and page policy.
Use a patched Rails line for deployed hosts; the retained 7.2 compatibility test
graph is not an endorsed deployment baseline.

## Next

No new package/advisory match remains in root or Rails 8. Future upstream updates
need fresh scans and integration checks. The existing Rails 7.2 disposition
remains with the operator. No upstream issue or public comment was posted.

## Source

- [GraphQL release notes](https://github.com/rmosolgo/graphql-ruby/blob/v2.6.15/CHANGELOG.md)
- [Interpreter authorization advisory](https://github.com/rmosolgo/graphql-ruby/security/advisories/GHSA-q3cc-p5hm-55wj)
- [Next executor authorization advisory](https://github.com/rmosolgo/graphql-ruby/security/advisories/GHSA-4rw8-495r-pf6j)
- [GraphQL package metadata](https://rubygems.org/api/v1/gems/graphql.json)
- [GraphQL integration metadata](https://rubygems.org/api/v1/gems/activeadmin-graphql.json)
- [Device authorization metadata](https://rubygems.org/api/v1/gems/activeadmin-device_authorization.json)
- [Existing Rails 7.2 advisory assessment](20261113120312_rails72-advisory-matches.md)
- [Setup guide](../activeadmin-agent-access.md)
