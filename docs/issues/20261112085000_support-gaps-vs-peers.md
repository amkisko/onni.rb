# Support gaps - onni vs upstream path gem + peers

## Participants

Andrei Makarov (@amkisko)

## Decisions

Research compared Onni to the upstream unpublished path gem it was extracted from, house peers (`activeadmin-device_authorization`, `data-migration`, `polyrun`), and typical feature-flag host call sites.

Remaining musts:

1. Commit appraisal `gemfiles/*.gemfile.lock` (peer DA has locks; CI/release assume them).
2. Rails/ActiveAdmin integration harness (engine + AR adapter + Features page) - unit suite is memory-only.
3. Expand specs (registry, conditions, group, config, generator) toward peer depth.
4. Expand `sig/onni.rbs` beyond a handful of methods.
5. Optional: `pull_request` CI trigger; `rfcs/` when API stabilizes; `spec_paths.txt` when suite grows.

Non-goals: a separate mountable flag UI; Redis adapters; evaluating `percentage_of_time` / `expression`; hard Rails/AA runtime dependency on the gem core; using Onni as access control.

## Effects

Fixed this pass:

- Zeitwerk ignore `app/admin` (upstream engine parity).
- Features page actions gated by `admin_authorized` (`head :forbidden`).
- Prior-library migrator skips `expression` / `percentage_of_time`; returns `skipped_gates`.
- README: conditions, stats, dashboard access, exist? contract, import/skip list.
- Explicit guidance: Onni is for flags / A/B / stats - not authorization; public examples use generic names only.

## Next

- Work the remaining musts above in forge order (locks, harness, specs, RBS, optional CI/RFC).
- Follow-up audit pass (20261112114500) closed Group boot freeze, AR stats upsert race, unparseable expiry fail-closed, and unit coverage for Group/Registry/Actor/Conditions. See `docs/reviews/20261112114500_iterative-engineering-audit.md`.
- Pass 3 (20261112120000) closed ActiveAdmin index hit pollution (`record_stats:`), variants gate import, Flag coverage, and RBS for Store/Stats/Migrator. See `docs/reviews/20261112120000_iterative-engineering-audit-pass-3.md`.
- Later passes added sampling controls, purge job generator, and ops instrumentation; keep public docs free of third-party product names.


## Source

- Upstream unpublished path gem (extraction source)
- Peers: `activeadmin-device_authorization`, `data-migration`, `polyrun`
- Typical feature-flag host call sites
