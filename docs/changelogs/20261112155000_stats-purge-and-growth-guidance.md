# Stats retention purge and growth guidance

## Participants

Andrei Makarov (@amkisko)

## Decisions

Ship batched hit-bucket cleanup in the gem: `Onni::Stats::Purge`, `Onni.purge_stats!`, `rails g onni:stats_cleanup` (ActiveJob + `period_start` index), default `stats_retention = 90.days`. Document host responsibility for partitioning and vacuum when the table exceeds about 1GB or 10M rows.

## Effects

- Adapters implement `purge_stats_batch` (id cursor, batch size).
- Console drain pages in-process; job enqueue pages the next batch.
- Install migration adds `index_onni_feature_stats_on_period_start`.
- README section "Stats growth and cleanup".
- Specs: memory + ActiveRecord purge paging.

## Next

- Hosts schedule `OnniPurgeStatsJob` daily after generating it.

## Source

- `lib/onni/stats/purge.rb`
- `lib/generators/onni/stats_cleanup_generator.rb`
- `README.md`
