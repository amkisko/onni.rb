# Features Assignment shows Delivery

## Participants

Andrei Makarov.

## Decisions

Label Flags index and detail overview with Delivery when
`Onni::Delivery.entries` owns the feature name. Keep Experiment for A/B
`type: experiment` flags. One Delivery per feature remains enforced in the
Delivery registry.

## Effects

Add `Flag#delivery?` and `Flag#assignment`. Features index Assignment column
and detail overview use that label. Delivery detail copy states one Delivery
owns the feature. Request coverage in delivery operator controls.

## Next

Shipped in 3.0.1.

## Source

- [Changelog draft](../changelogs/20261116093400_features-assignment-delivery.md)
