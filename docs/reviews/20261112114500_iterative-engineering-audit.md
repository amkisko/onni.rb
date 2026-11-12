# Iterative engineering audit - Group, stats, expiry, specs

## Participants

Andrei Makarov (@amkisko)

## Decisions

Pipeline: YAML registry ingress -> Store evaluate -> adapter gates -> optional host cache -> stats egress. Boundary mode covered ActiveAdmin `admin_authorized` only (no physical actuators). Resource and budget mode: no new hot-path algorithm; upsert replaces find_or_create on stats write. Trace and identification: actor ids and feature keys unchanged. Security mode: no new trust boundary; fail-closed expiry tightened. Durable-cache: gate cache key and bust paths unchanged.

Suitable for this gem (kept in scope): boot Group registry, AR stats write race, unparseable expiry fail-closed, spec isolation, unit coverage for Group/Registry/Actor/Conditions. Out of scope this pass: Redis adapter, percentage_of_time, expression gates, audit log, Bayesian analysis, separate mountable flag UI.

## Effects

Pass 1 findings fixed:

- High (contract): `Onni::Group.register` raised `FrozenError` on the boot empty registry because `@registry` started frozen. Specs hid it with `clear!`. Fixed by a mutable boot hash and dup-if-frozen on register. Spec proves boot register without prior clear.
- Medium (database / concurrency): ActiveRecord `record_stat` used find_or_create then update_all. Replaced with `upsert` on `index_onni_feature_stats_unique` with column increment on duplicate. Spec covers multi-hit increment.
- Medium (test isolation): `store_spec` left `stats_enabled = false` for later request examples. Restored config in an around block; `rails_helper` before resets stats/cache/admin_authorized.

Pass 2 findings fixed:

- Medium (contract): unparseable `expires_at` used to fail open (flag stayed evaluable). `Store#expired?` now fails closed when parse raises. README and CHANGELOG updated.
- Low (coverage): added Group, Registry, Actor, Conditions specs; store examples for `disable_group`, percentage clamp, and unparseable expiry.

Validation: `bundle exec rspec` -> 40 examples, 0 failures (seed 18009 and repeated random seeds including 24176).

## Next

- Done: expanded `sig/onni.rbs` for Store/Adapters/Migrator/Registry/Group/Actor/Conditions/Instrumenter/Buffer.
- Done: README ActiveRecord upsert dialect note (`excluded.updated_at`).
- Non-goals remain: Redis adapters, expression gates, using Onni as authorization.

## Source

- `lib/onni/group.rb`
- `lib/onni/adapters/active_record.rb`
- `lib/onni/store.rb`
- `spec/onni/group_spec.rb`
- `spec/onni/registry_spec.rb`
- `spec/onni/actor_spec.rb`
- `spec/onni/conditions_spec.rb`
- `spec/onni/store_spec.rb`
- `spec/rails_helper.rb`
- `docs/reviews/20261112084200_engineering-audit.md`
- `docs/issues/20261112085000_support-gaps-vs-peers.md`
