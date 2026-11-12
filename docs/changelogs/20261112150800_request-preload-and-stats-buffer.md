# Request preload and stats buffer

## Participants

Andrei Makarov (@amkisko)

## Decisions

Ship fiber-local request preload and optional stats coalescing so hosts can cut adapter reads and hit writes per request. Keep both opt-in at the call site / `stats_buffer` flag. Measure before/after on the all-features L1 observe probe.

## Effects

- `Onni.preload!`, `Onni.flush_stats!`, `Onni.reset_request!`
- Adapter `gates_for_many` (memory + ActiveRecord)
- `config.stats_buffer` (default false)
- Lean `Store.variant` (single gates fetch)
- Observe L1 (N=10000, SAMPLES=5), memory adapter:
  - before: wall ~0.164s, alloc ~693592
  - after preload+buffer: wall ~0.138s (-16%), alloc ~509001 (-27%)
  - gate with preload+buffer: PASS under existing ceilings
- Specs: preload, buffer, lean variant, AR gates_for_many

## Source

- `tmp/bench/baseline_before_improvements.log`
- `tmp/bench/after_preload_and_buffer.log`
- `tmp/bench/gate_after_improvements.log`
