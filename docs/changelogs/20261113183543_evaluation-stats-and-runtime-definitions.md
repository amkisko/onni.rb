# Evaluation statistics and runtime definitions

Working-tree implementation draft; no release has been cut.

## Participants

Andrei Makarov.

## Decisions

Implement RFC-0006 and RFC-0007. Collect completed evaluations of known features
by default, including pending and parked misses. Keep call-site, feature, and
application controls. Provide explicit programmatic definitions with mandatory
description and expiration while recommending features.yml for the team.

## Effects

Known off-state visible? and unassigned variant calls now record skips. Feature
YAML accepts collection and sample-rate defaults; stats! changes them without
changing power. Ordinary application configuration preserves the current
adapter. Buffered counts survive turning buffering off until cleanup or flush.
Reattaching a cache cannot resurrect gates changed while caching was disabled.
The install initializer now samples all calls by default and retains buffering.

define! validates and copies a complete process-local definition. Reloads retain
it and reject collisions with YAML names. Replacements preserve stored gates
and counters. README and RFCs explain lifetime, strictness, and the preferred
shared catalogue. No admin explanatory panels were added.

## Next

Review the contract changes and select a release. Assess the measured runtime
cost and the earlier aggregate budget findings before publication.

## Source

- [Implementation and verification](../issues/20261113174758_evaluation-stats-and-runtime-definitions.md)
- [RFC-0006](../../rfcs/0006-evaluation-statistics-policy.md)
- [RFC-0007](../../rfcs/0007-programmatic-feature-definitions.md)
- [Resource comparison](../../benchmarks/evaluation_stats_binding.md)
