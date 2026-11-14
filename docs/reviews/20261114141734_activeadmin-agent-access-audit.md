# ActiveAdmin agent access engineering audit

## Participants

Andrei Makarov.

## Decisions

Implement RFC-0012 as an optional operator API, tested with the published
activeadmin-graphql 0.4.1 and activeadmin-device_authorization 0.2.0 packages.
The host owns bearer authentication, consent, token lifecycle and page policy.
Onni supplies typed catalogue snapshots and named domain commands. A separate
CLI or MCP server is outside this contract; both can use its HTTP transport.

Review ingress, contracts, authorization, dynamic schema caching, persistence,
egress, resource/budget, performance, trace/identification, privacy and operator
control boundaries. Inspect the guide as the new person-facing surface. Skip
learned systems, background queues, physical controls and native UI modes:
none are introduced here. Existing HTML feature controls are unchanged.

Use failing executable specs before repairs. Keep the core's zero runtime
dependencies and preserve incoming release-preparation changes. Do not publish
packages or send an upstream issue from this task.

## Effects

### Iterative findings and repairs

1. The first four request examples had three failures: the custom Features page
   supplied neither its catalogue query nor commands. Add the explicit page field
   and schema hook. This also works with generic policies/resources disabled.
2. Boundary specs exposed two scalar defects: explicit null thresholds were
   rejected, and Ruby Integer accepted underscore-separated strings. Accept null
   only where the schema permits it and validate decimal signed-64 input before
   conversion. Floats, overflow and malformed strings leave gates unchanged.
3. A collision with a later host mutation name previously left earlier Onni
   commands installed. The regression failed with 32 examples, 1 failure. Preflight
   all names before adding fields. Existing host fields and repeat installation
   now survive without partial Onni installation. A final inherited-field
   regression then failed with 10 examples, 1 failure: own_fields omitted host
   base-class fields. Preflight all_field_definitions instead. The focused
   suite returns to 33 examples, 0 failures.
4. The intermediate cached GraphQL 2.6.10 resolution matched four advisories.
   Verify upstream changes and all new package digests, then require 2.6.15 in
   the manifest and optional loader. The dependency note owns the impact map.
5. Fresh scoped requests cover read-only introspection, denied host policy,
   disabled/revoked/expired identities and CSRF. A positive host callback reads
   the actual request principal. Cached schemas do not transfer write fields or
   private input types to a read-only token. Denied reads hide OnniFeature too.
6. An existing SQLite Delivery probe unintentionally inherited four new host
   identity tables. Its initial expanded-fixture sample exceeded fallback p95
   (1204 us against 1183.35) and export p95 (116 us against 115). A five-sample
   repeat also exceeded both; there were no lost increments or write failures.
   The pre-task three-table control stayed within the old limits. Extract the
   existing Onni schema so the core probe retains its original fixture, while
   the integration host still loads all tables. The restored probe passes the
   unchanged performance limits. This is a fixture repair, not a claimed runtime
   optimization; host load remains a possible source of timing variation.
7. The last structure check found an overlong installation decision expression.
   Extract its existing visibility guard, rerun focused specs, and retain the
   same fail-closed configuration behavior.

### Request pipeline and control

The device request, signed-in consent and single-use token exchange run through
real package controllers and fixture records. GraphQL authentication runs before
introspection and CSRF. The host bridge accepts only enabled allowed clients,
active owners and unexpired, unrevoked tokens; insufficient read scope returns
403, invalid credentials return 401. Authentication updates last-used only after
success. The CSRF exemption requires a validated bearer principal, not a header.

The namespace's capability callback and page authorization gate both visibility
and execution. Read scope is required for snapshots; commands require read plus
write scope and their corresponding Features page action. A host denial wins.
The schema preserves unrelated host fields. Dynamic visibility uses preload:
false. Clearing the process schema cache rebuilds from ActiveAdmin registrations
and the configure hook; it does not revoke a durable token or reset feature data.

Snapshots read adapter state directly instead of evaluating a feature or using
a stale visibility cache. Lists sort the registered catalogue, O(n log n), then
read at most 100 selected names in one gate batch; custom non-batching adapters
fall back to one read per selected name. Catalogue size is process-local, not a
scan of all stored gates. Statistics are bounded to 720 hours. Commands dispatch
through a fixed whitelist to the existing Ruby mutations, never arbitrary host
code or raw table CRUD. A successful response contains a fresh snapshot. A 200
response with GraphQL errors is not command success.

Operator snapshots can include existing audience identifiers. The guide states
that privileged data scope and consent belong to the host. The extension adds no
actor tracking identifier. Disposable credentials stayed in memory/private pipes,
not command arguments, persisted fixtures or output logs. The fixture's permissive
rate-limit callbacks and stubbed consent principal are not deployment policy.

### Resource and pressure evidence

Three alternating fresh-process boot samples per side compare an isolated
pre-task working-tree snapshot with the final source. The base is not represented
as a clean revision. Raw samples identify both source hashes, the probe, machine,
Ruby version, UTC times and revision. CPU is the energy proxy; RSS is
process_lifetime, not a stage allocation measurement. Registry transfer volume
is not measured; these resource probes perform no remote IO.

Final median dummy-host boot delta: CPU +54.169 ms, wall
+53.990 ms, peak RSS +10682368 bytes. Resolved installed gem
graph bytes grow by 2598575; package count grows from 113 to 117.
The compressed gem grows from 63488 to
67584 bytes (+4096). These are optional
host/test costs, not a claim that the extension is faster or smaller. Core
runtime dependency count remains zero on both sides.

Uncompressed lib/app/sig grows from 143786 to 160193 bytes. The explicit scope
allowance adds 16407 bytes to the memory source ceiling: 148000 -> 164407.
The durable source ceiling already fits; all performance, RSS, storage and
correctness ceilings remain unchanged.

Recalibration separates success/fallback/observe/export fixtures at 11/23/37/53
us and passes the direct stage-versus-wall check. Final core gates use WRITERS=8,
OPS=100, three fresh samples each, memory and disposable SQLite adapters. Both
pass every recorded limit and retain all 1600 increments per sample with zero
write/level errors. The earlier 12-cycle Delivery cooker remains its own frozen
episode; these are follow-up gates and dependency comparisons, not a new ten-cycle
GraphQL throughput benchmark or a soak test.

### Product surface and claim checks

The new person-facing surface is docs/activeadmin-agent-access.md plus schema
introspection. Review the guide's order: install, host authentication, discover,
read, command and credential-safe curl. Typed names, unknown/empty values,
permission failures and malformed-input states are exercised through requests.
The document remains plain, readable prose on a narrow view. There is no new
visual application screen, loading interaction or screenshot requirement in
this change. A real host's sign-in, consent UI, accessibility and production
rate limits still need that host's assessment.

Contrary checks preceded acceptance: shared-cache token order, denied callbacks,
unknown names, absent read scope, invalid credentials, numeric overflow, late
field collisions and fixture drift. This implementation and review share the
same agent context; these are executable checks, not an independent human audit.

Claim ledger:

- Optional schema and policy isolation in the guide/RFC: supported by request
  specs and standalone boot specs. Scope is the tested host configuration.
- Published package versions, provenance and security floor: supported by
  RubyGems metadata, checked package digests, lockfile checksums and upstream
  release/advisory sources in the dependency note.
- Runtime/graph/artifact deltas: supported by the frozen raw resource report.
  No whole-product speed, energy or deployment-size superiority is claimed.
- curl compatibility: supported by a real local HTTP client probe, 401 without
  authentication, 200 query, 200 Ready mutation, with CSRF protection enabled.
- Particular CLI or MCP server compatibility: unverified and not claimed. The
  guide limits its statement to clients using the same GraphQL HTTP contract.

### Validation commands and observed results

- BUNDLE_IGNORE_CONFIG=1 bundle exec rspec
  -> 527 examples, 0 failures.
- BUNDLE_IGNORE_CONFIG=1 bundle exec rspec spec/requests/agent_graphql*_spec.rb
  -> 33 examples, 0 failures.
- BUNDLE_IGNORE_CONFIG=1 BUNDLE_GEMFILE=gemfiles/rails72.gemfile POLYRUN_SHARD_INDEX=72 bundle exec rspec spec/requests/agent_graphql*_spec.rb
  -> 33 examples, 0 failures, Ruby 4.0.2 / ActiveRecord 7.2.4.
- BUNDLE_IGNORE_CONFIG=1 BUNDLE_GEMFILE=gemfiles/rails8ruby34.gemfile POLYRUN_SHARD_INDEX=834 bundle exec rspec spec/requests/agent_graphql*_spec.rb
  -> 33 examples, 0 failures, Ruby 4.0.2 / ActiveRecord 8.1.4.1.
- BUNDLE_IGNORE_CONFIG=1 BUNDLE_GEMFILE=gemfiles/rails8ruby4.gemfile POLYRUN_SHARD_INDEX=804 bundle exec rspec spec/requests/agent_graphql*_spec.rb
  -> 33 examples, 0 failures, Ruby 4.0.2 / ActiveRecord 8.1.4.1.
- RBENV_VERSION=3.4.10 BUNDLE_IGNORE_CONFIG=1 BUNDLE_GEMFILE=gemfiles/rails8ruby34.gemfile BUNDLE_PATH="$PWD/tmp/ruby34-bundle" POLYRUN_SHARD_INDEX=340 bundle exec rspec spec/requests/agent_graphql*_spec.rb
  -> 33 examples, 0 failures, actual native Ruby 3.4.10 / ActiveRecord 8.1.4.1.
- BUNDLE_IGNORE_CONFIG=1 ruby tmp/agent_graphql_curl_probe.rb
  -> actual curl client, 401 unauthenticated, 200 read, 200 command, READY.
     The temporary probe issued a disposable device credential and served the
     full Rails application over loopback. Repeatable protocol coverage is in
     the maintained request specs; the raw sanitized result is retained below.
- BUNDLE_IGNORE_CONFIG=1 bundle exec rubocop --cache false --format simple
  -> 145 files inspected, no offenses.
- BUNDLE_IGNORE_CONFIG=1 bundle exec rbs validate
  -> exit 0.
- ruby usr/bin/check_locale_parity.rb
  -> Locale parity ok: en (2 keys).
- ruby usr/bin/check_loc.rb
  -> exit 0; existing long-file warnings for app/admin/features.rb,
     lib/onni.rb and usr/lib/release_version_check.rb.
- git diff --check
  -> exit 0.
- BUNDLE_IGNORE_CONFIG=1 bundle exec ruby benchmarks/delivery_pressure.rb --calibrate
  -> calibration pass; raw distinct stages retained below.
- BUNDLE_IGNORE_CONFIG=1 CEILINGS=benchmarks/delivery_ceilings.json bundle exec ruby benchmarks/delivery_pressure.rb
  -> three samples, failed: [], zero write_errors/level_error.
- BUNDLE_IGNORE_CONFIG=1 ADAPTER=active_record CEILINGS=benchmarks/delivery_active_record_ceilings.json bundle exec ruby benchmarks/delivery_pressure.rb
  -> three samples, failed: [], zero write_errors/level_error.
- BUNDLE_IGNORE_CONFIG=1 bundle exec ruby benchmarks/agent_graphql_resources.rb
  -> three alternating boot samples per side and two successful local gem builds.
- BUNDLE_IGNORE_CONFIG=1 BUNDLER_AUDIT_DB=tmp/ruby-advisory-db bundle exec bundler-audit check --gemfile-lock Gemfile.lock
  -> No vulnerabilities found. The same check with --gemfile-lock
     gemfiles/rails8ruby34.gemfile.lock and gemfiles/rails8ruby4.gemfile.lock also
     reports no vulnerabilities. Advisory DB revision is recorded in the
     security-floor note. Rails 7.2 retains 18 previously assessed matches;
     the linked existing note owns their unresolved disposition.

## Next

Implementation and local validation are complete. Maintainer release review
and real host adoption remain. Configure that host's actual authentication,
consent policy, trusted origin, rate limits and token secret storage. Run its
own CLI/MCP client and production database/cache topology before claiming those
specific integrations are certified. No package was published from this task.

## Source

- [Live work](../issues/20261114131240_activeadmin-graphql-device-access.md)
- [RFC-0012](../../rfcs/0012-activeadmin-graphql-operator-api.md)
- [Setup guide](../activeadmin-agent-access.md)
- [Dependency security assessment](../dependencies/20261114140515_optional-graphql-security-floor.md)
- [SQLite default compatibility defect](../dependencies/20261114140515_rails72-sqlite-boolean-defaults.md)
- [Resource samples](../../benchmarks/agent_graphql_resources.json)
- [Memory gate](../../benchmarks/agent_graphql_core_gate.json)
- [SQLite gate](../../benchmarks/agent_graphql_active_record_gate.json)
- [Fixture investigation](../../benchmarks/agent_graphql_fixture_comparison.json)
- [Meter calibration](../../benchmarks/agent_graphql_calibration.json)
- [curl result](../../benchmarks/agent_graphql_curl_result.json)
- [Earlier cooker episode](20261114123346_delivery-implementation-audit.md)
