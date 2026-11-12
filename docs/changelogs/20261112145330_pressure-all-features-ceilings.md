# Pressure ceilings for all-features evaluate probe

## Participants

Andrei Makarov (@amkisko)

## Decisions

Replace the single-path `enabled?` pressure probe with an all-features walk (boolean, actor, percentage, group, variant, conditions, stats sample) and accept new L1 ceilings from median x 1.25.

## Effects

- Binding and harness updated under `benchmarks/`
- `benchmarks/ceilings.json` rewritten for the expanded probe
- Episode accepted: `docs/issues/20261112145330_pressure-all-features-episode.md`
- Calibrate PASS; 10 L1 prove cycles PASS

## Source

- `docs/issues/20261112145330_pressure-all-features-episode.md`
