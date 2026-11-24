# Puma 8.1.1 advisory matches need 8.1.2

## Participants

Andrei Makarov.

## Dependency

Package: puma. Locked version: 8.1.1 in Gemfile.lock and all three
gemfiles/*.gemfile.lock. Development dependency floor: >= 5.0.
Registry latest at audit time: 8.1.2 (published 2026-11-17). Advisory
database: ruby-advisory-db revision
c87703e7f2c64f8745ce032711308a17d10cda55 (2026-11-22).

## Symptom

Trigger: bundler-audit matches two advisories on every CI lockfile that
resolves puma.

## Evidence

Command: `bundle exec bundler-audit check --gemfile-lock Gemfile.lock`
(and the appraisal locks). Observed exit: 1. Matches:

- GHSA-4v6q-hvv7-49h9 (Moderate): memory exhaustion on MRI when Puma binds
  with ssl:// or ssl_bind. Plain TCP and Unix binds are not affected.
  Patched in 8.1.2.
- GHSA-rhww-p99c-hgj9 (Moderate): JRuby HTTP parser lets request headers
  change PATH_INFO and QUERY_STRING. Advisory text: MRI is not affected.
  Patched in 8.1.2.

Tier: development and test only (dummy app and system specs). Search of
spec/dummy finds no ssl_bind or ssl:// configuration. CI matrix uses MRI
Ruby 3.4 and 4.0, not JRuby.

Assessment target: Onni CI and dummy-app test graph on MRI with plain binds.
Status for GHSA-4v6q-hvv7-49h9: not_affected. Applicability: vulnerable code
not in the execute path (no SSL bind in this fixture).
Status for GHSA-rhww-p99c-hgj9: not_affected. Applicability: component
platform not present (JRuby required).

Assessment target: any lockfile that still resolves 8.1.1 for a host that
might enable ssl_bind. Status: fixed for this repository's lockfiles.
Resolved puma is 8.1.2; development floor is >= 8.1.2. Observed:
`make audit` reports no vulnerabilities on Gemfile.lock and both Rails 8
appraisal locks.

## Suggested fix

Applied: puma >= 8.1.2 in onni.gemspec and every lockfile.

## Next

None for the Puma advisory matches on the scanned non-skipped lockfiles.

## Source

- Live remediation queue: ../issues/20261123163709_lockfile-security-bumps.md
- https://github.com/puma/puma/security/advisories/GHSA-4v6q-hvv7-49h9
- https://github.com/puma/puma/security/advisories/GHSA-rhww-p99c-hgj9
- https://rubygems.org/gems/puma/versions/8.1.2
