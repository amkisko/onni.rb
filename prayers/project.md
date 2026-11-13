# Project

Onni provides typed feature flags, gradual rollout, experiments, audience groups,
and evaluation statistics for Ruby apps, with pluggable ActiveAdmin support.

Use ready!/park! for runtime power and ready?/pending?/parked? for its states.
Use visible? for actor visibility, visible_*/drop_* for audience slices, and
level!/level for the percentage dial. Stats use shown_count/skip_count and
shown_share. The v1 API has no enable/disable or transitional show/skip aliases.

Onni is for experiments and rollout visibility, not authorization. Keep
privileged actions behind the host's policy layer.

Use generic public feature names such as new_checkout, search_v2, and beta_testers.
Do not put private product or host-specific names in public documentation.

Default branch: main. Repository: https://github.com/amkisko/onni.rb
