# Implement show/skip typed flags

## Participants

Andrei Makarov (@amkisko), named in the source plan.

## Decisions

Vocabulary amendment: the direct v1 implementation supersedes this episode's
show/skip API and compatibility window. Current contracts and validation live in
[the ready/park/visible issue](20261113091112_ready-park-visible-terminology.md)
and amended RFC-0003. Preserve this episode's historical measurements.

Implement the requested plan under RFC-0003. Use percentage naming, explicit
actor methods, boolean as the omitted type, clear as hard-off, and showing/skipped
admin scopes. Keep deprecated Ruby aliases during 0.x; remove them at 1.0.
Defer request/actor count deduplication and gate-key renaming. Runtime overrides
take precedence over YAML defaults, including empty audience overrides.

Prefer positive predicates where their meaning fits. show? evaluates visibility;
skip? inspects hard-off state, so they are not inverses for a powered audience
miss. Admin power-state branches use skip? directly; showing filters reject
skipped flags rather than negating skip? or substituting visibility evaluation.

## Effects

Implementation and validation are recorded in the [engineering changelog](../changelogs/20261113062000_show-skip-typed-flags.md).

The positive-predicate follow-up removes negated skip? calls from admin branches,
status copy, scope filtering, and counts without changing visibility semantics.
Add regression coverage for powered zero-percent flags in scopes and detail status.
bundle exec rspec spec/onni/admin/flags_query_spec.rb spec/requests/admin_features_spec.rb
passed 17 examples. bundle exec rspec passed 185 examples, zero failures, seed
16244. RUBOCOP_CACHE_ROOT=tmp/rubocop-cache make lint and git diff --check passed.

Automatic approval review rejected the local project-description update twice,
interpreting .agents/project.md as a protected provisioned file. That source and
managed AGENTS.md remain unchanged. The temporary Prayfile syntax edit was
reverted. No rejected write was executed.

## Next

- Obtain operator approval for the remaining project-description vocabulary update.
- Review the styled ActiveAdmin host at desktop and narrow widths; the dummy app has no ActiveAdmin stylesheet.
- Coordinate the stats column rename and application deployment for existing hosts.
- Defer request/actor deduplication and legacy gate-key renaming. Remove Ruby aliases at 1.0.

## Source

- [Plan](../plans/20261113054615_show-skip-terminology-v1.md)
- [RFC-0003](../../rfcs/0003-show-skip-typed-flags.md)
- [Engineering changelog](../changelogs/20261113062000_show-skip-typed-flags.md)
