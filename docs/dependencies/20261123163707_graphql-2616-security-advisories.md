# GraphQL 2.6.15 advisory matches need 2.6.16

## Participants

Andrei Makarov.

## Dependency

Package: graphql. Locked version: 2.6.15 in Gemfile.lock and all three
gemfiles/*.gemfile.lock. Manifest floor in onni.gemspec and the optional
loader: >= 2.6.15, < 3. Registry latest at audit time: 2.6.16 (published
2026-11-17). Advisory database: ruby-advisory-db revision
c87703e7f2c64f8745ce032711308a17d10cda55 (2026-11-22).

## Symptom

Trigger: bundler-audit matches three advisories on every CI lockfile that
resolves graphql.

## Evidence

Command: `bundle exec bundler-audit check --gemfile-lock Gemfile.lock`
(and the same for gemfiles/rails72.gemfile.lock,
gemfiles/rails8ruby34.gemfile.lock, gemfiles/rails8ruby4.gemfile.lock).
Observed exit: 1 on each lockfile. Matches:

- GHSA-492h-6x29-69mq (High): `.authorized?` skipped after crafted connection
  cursors when a schema has a connection whose node type uses
  `reauthorize_scoped_objects(false)`. Patched in 2.6.16.
- GHSA-wqwf-8p4q-mwqj (High): exponential time in complexity analysis when
  `max_complexity` is set. Patched in 2.6.16.
- GHSA-5f8h-c2xc-j37j (Medium): exponential lexer backtracking on Rubies
  <= 3.2.x. Patched in 2.6.16.

Static search in this tree finds no GraphQL::Pagination connection types and
no `reauthorize_scoped_objects`. Feature listing uses a custom FeaturePage
cursor, not the library connection machinery. No `max_complexity` setting
appears in this repository. required_ruby_version is >= 3.4.0; CI runs 3.4
and 4.0.

Assessment target: Onni optional ActiveAdmin GraphQL API (lib/onni/admin/graphql).
Status for GHSA-492h-6x29-69mq: not_affected. Applicability: vulnerable code
not in the execute path for this schema (no matching connections).
Status for GHSA-wqwf-8p4q-mwqj: not_affected. Applicability: attack condition
requires `max_complexity`; not configured here.
Status for GHSA-5f8h-c2xc-j37j: not_affected. Applicability: requires Ruby
<= 3.2.x; this project and its declared consumers require >= 3.4.0.

Assessment target: development and appraisal lockfiles locking graphql 2.6.15.
Status: fixed. Locks and floors now resolve graphql 2.6.16. Observed:
`make audit` reports no vulnerabilities on Gemfile.lock and both Rails 8
appraisal locks. `bundle exec rspec spec/requests/agent_graphql*.rb` ->
33 examples, 0 failures. Loaded GraphQL::VERSION is 2.6.16.

Priority inputs: high technical severity on two advisories; fix available as
patch 2.6.16; remediation cost is a lock and floor bump. No KEV entry checked
in this pass beyond the published GHSA pages.

## Suggested fix

Applied: graphql >= 2.6.16 in onni.gemspec, lib/onni/active_admin_graphql.rb,
host docs, and every Gemfile.lock / gemfiles/*.gemfile.lock.

## Next

None for the GraphQL advisory matches on the scanned non-skipped lockfiles.

## Source

- Live remediation queue: ../issues/20261123163709_lockfile-security-bumps.md
- Prior floor note: 20261114140515_optional-graphql-security-floor.md
- https://github.com/rmosolgo/graphql-ruby/security/advisories/GHSA-492h-6x29-69mq
- https://github.com/rmosolgo/graphql-ruby/security/advisories/GHSA-wqwf-8p4q-mwqj
- https://github.com/rmosolgo/graphql-ruby/security/advisories/GHSA-5f8h-c2xc-j37j
- https://rubygems.org/gems/graphql/versions/2.6.16
