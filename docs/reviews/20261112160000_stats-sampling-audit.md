# Stats sampling audit

## Participants

Andrei Makarov (@amkisko)

## Decisions

Tighten hit-stat sampling for counter storage: clamped 0.0..1.0 rates, skip Random at 1.0, optional sampler callable, ignore list, and optional inverse-rate weighting of kept samples.

Pipeline: Store evaluate -> Stats.record -> Sampler.decide -> adapter.record_stat(weight) -> upsert/memory bucket. Observability mode: hit buckets are operator telemetry; scaled counts are estimates. Resource and budget: skip Random when rate is 1.0; ignore list avoids write amplification on noisy keys. Trace and identification: still stores feature_key only in buckets (no new person identifiers). Security: unchanged. Boundary/control: not applicable (library IO only via host DB).

Out of scope: treating rates above 1.0 as percentages, parent-trace inheritance, remote agent storage.

## Effects

Findings fixed:

- Medium (contract): `stats_sample_rate` outside 0..1 was not clamped (rate > 1 skipped the Random branch and always recorded). Setter now clamps via `Stats::Sampler.coerce_rate`.
- Medium (observability): sampled hits under-reported full traffic with no contract. Default `stats_scale_sampled_hits = true` increments by ~1/rate on kept samples. Raw kept counts available when scaling is false.
- Low (hot path): rate 1.0 now returns weight 1 without `Random.rand`.
- Low (product): added `stats_sampler` and `stats_ignore`.
- Coverage: Sampler and record specs; AR weight upsert example.

Validation: `bundle exec rspec` -> 64 examples, 0 failures (at landing; suite grew afterward).

## Next

- Done: README notes hot-flag `stats_ignore` / low `stats_sampler` before lengthening retention alone.
- Done: ActiveAdmin feature show panel shows effective hit sample rate (off / ignored / global rate).

## Source

- `lib/onni/stats/sampler.rb`
- `lib/onni/stats.rb`
- adapters
- `README.md`
