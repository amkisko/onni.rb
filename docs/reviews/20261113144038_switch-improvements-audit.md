# Switch improvements engineering audit

## Participants

Andrei Makarov.

## Decisions

Audit covered migrate ingress, ActiveAdmin load path, install-generator defaults, and host test helper. Boundary/control skipped (library, no physical actuators). Privacy skipped (no new person identifiers). Security: SQL uses connection quoting only; no third-party feature-flag gem dependency for import.

## Effects

Pipeline: prior SQL tables -> ActiveRecordTables source -> Importer -> adapter gates -> visible? egress.

Findings addressed this pass:

1. High (boot): ActiveAdmin `app/admin` registered after `load!` in production. Fixed with `ActiveAdmin.before_load`. Evidence: failing unload/load spec before fix; green after.
2. Medium (cutover): hosts needed hand SQL for prior feature/gate tables. Added ActiveRecordTables + README checklist. Evidence: importer already maps boolean to powered; source specs read quoted tables.
3. Medium (hot path / resource): install generator defaulted `stats_sample_rate = 1.0` with buffer commented off. Template now buffer on and sample 0.1. Configuration class default remains 1.0 for non-generated hosts (document, do not surprise existing apps).
4. Low (product surface): Ready on empty `type: group` still looks like "on for everyone". Deferred UI; README states ready alone is invisible for empty groups.
5. Low (contracts): Prior OR of boolean+groups has no Onni equivalent. Importer skips type-incompatible gates; checklist requires one type per flag. Supported by existing mixed-gate importer spec.
6. Low (actor identity): Prior actor values may not match `Onni::Actor.id`. Documented; no silent rewrite (would hide mismatches).
7. Low (docs): Public API and README avoid naming other feature-flag gems; hosts pass their own table names.

Modes run: core dimensions, pipeline, resource and budget (stats defaults only; no new bench numbers this pass), trace and identification (actor id note), contracts, product-surface (Ready semantics). Observability unchanged. Learned-systems and lineage skipped.

## Next

- Optional: admin Ready-for-everyone or empty-group warning.
- Optional: measure host stats write rate before/after generator default change on a real app.

## Source

- `docs/issues/20261113144038_switch-upstream-improvements.md`
- `spec/onni/active_admin_load_path_spec.rb`
- `spec/onni/migrator_active_record_tables_spec.rb`
- `spec/onni/migrator_importer_spec.rb`
