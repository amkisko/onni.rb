# Rails 7.2 compatibility graph advisory matches

## Participants

Andrei Makarov (@amkisko), the current operator.

## Dependency

Target: gemfiles/rails72.gemfile.lock, the existing Rails compatibility test graph.
Constraint: Rails ~> 7.2 and >= 7.2.3.2. The resolved Rails components are 7.2.4.
The standard-library core has no runtime dependency on these components;
optional framework extensions use the host's installed packages.

## Symptom

Trigger: the required dependency-change scan reports 18 package/advisory matches
for the Rails 7.2 test graph. The root and both Rails 8 variant scans report zero
matches against the same advisory database. A match is not proof of an exploit
in the Onni fixture or an unnamed downstream application.

## Evidence

Command: `bundle exec bundler-audit check --database tmp/stdlib-core/advisories --gemfile-lock gemfiles/rails72.gemfile.lock`.
Observed exit: 1. Counts: actionmailbox 1, actionpack 6, actionview 4,
activestorage 6, activesupport 1. The structured scan results retain all 18 IDs
and source URLs in the linked episode evidence.

Database: 1359 advisories, revision 4d71b123428e33f694e805ce15351ee3d8d62ef7,
last updated 2026-11-11. It was downloaded into the workspace for this run.
No package version changed during the core extraction.

Assessment target: standalone Onni core artifact and consumer graph.
Status: not_affected for these matches, component not present. The new gemspec
declares zero runtime dependencies, the isolated consumer lock has no framework
components, and the guarded core fixture rejects framework requires.

Assessment target: Rails 7.2 compatibility test graph.
Status: under_investigation. The matching components are present. This episode
did not demonstrate attacker-controlled execution of every affected framework
surface. The dummy app loads ActiveRecord, controller, and view railties; it
does not load Action Mailbox, Action Cable, or Active Storage railties.
Static search finds no Onni call to safe_constantize or request-parameter
each_key return passed to mass assignment. Those observations narrow individual
paths and do not dispose of all 18 reports or downstream host configurations.

Priority: assess the retained compatibility graph before using it as a deployable
host baseline. No risk acceptance or successful exploitation is recorded here.

## Suggested fix

Evaluate the scanner's listed patched framework lines in a separate host/CI
change, or apply and verify upstream patches if retaining the older line is
required. The standard-library extraction removes the unconditional core edge;
it does not patch a host application's framework. Keep the scan failure visible
instead of treating the existing Makefile skip as a successful audit.

## Next

Andrei Makarov owns the compatibility-line decision. Close the test-graph
assessment after either a patched lockfile and compatibility checks, or scoped
reachability evidence for each advisory and an explicit disposition. Unnamed
downstream applications remain unassessed.

## Source

- [Live core extraction](../issues/20261113113242_stdlib-core-and-extensions.md)
- [Structured scan evidence](../../benchmarks/stdlib_core_results.json)
- [Advisory database revision](https://github.com/rubysec/ruby-advisory-db/tree/4d71b123428e33f694e805ce15351ee3d8d62ef7)
- [ActiveSupport advisory](https://github.com/rails/rails/security/advisories/GHSA-8474-xrp6-wh69)
- [Strong Parameters advisory](https://github.com/rails/rails/security/advisories/GHSA-wm3x-v3qw-4jh3)
