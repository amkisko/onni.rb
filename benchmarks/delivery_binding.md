# Delivery pressure binding

Measure: `BUNDLE_IGNORE_CONFIG=1 bundle exec ruby benchmarks/delivery_pressure.rb`.
Calibrate: append `--calibrate` before any baseline. The self-test separates
success/fallback/observe/export p95 values 11/23/37/53 us and compares one
measured stage against the wall aggregate. Peak RSS uses a separately parsed
`/usr/bin/time -l` process result. Run with process-stat permissions.

Load axis: WRITERS=1 then WRITERS=8, OPS=100 per writer. Each loop runs a
successful Delivery, a rescued failure, an explicit observe, and runtime JSON
export. At pressure: 800 loops, 1600 committed increments. SAMPLES defaults to
3; gate/propose/write need at least 3. The final noise check used 5.

Memory class: process_lifetime, isolated child per sample. CPU/wall cover warm
work; RSS includes interpreter and fixtures. CPU milliseconds are the energy
proxy. Network is not_in_scope: fixtures are memory or local SQLite. Storage
means retained serialized gates for memory, and SQLite files including WAL for
the durable probe. shipped_source_bytes is uncompressed lib/app/sig; the built
gem's compressed size is recorded separately in the work note.

ADAPTER=active_record selects local disposable SQLite with the same loop.
No production database is configured or used. Both adapters must finish with
zero write_errors and level_error. A distinct process correctness probe is
`BUNDLE_IGNORE_CONFIG=1 bundle exec ruby benchmarks/delivery_processes.rb`.
It forks 8 independent connections, 100 increments each, in 3 fresh databases;
the final level must be 800 and exactly one park notification must be emitted.
It is a correctness probe, not an aggregate process RSS measurement.

Ceilings: delivery_ceilings.json and delivery_active_record_ceilings.json.
Gate: set CEILINGS to the appropriate file in the measure command. The harness
fails closed if RSS cannot be measured. Proposal/write is manual review of raw
JSON samples; the harness never silently promotes a noisy sample.

Basis: max across samples times 1.15 for timing/CPU/RSS. Memory stage latency
limits use max observed across the ten iterations plus the five final noise
samples, with an explicit allow-raise decision in the live-work note. The RSS
limit remains the initial pressure ceiling. Wall and CPU use the final five
noise samples times 1.15, lower than the initial ceilings. The fixture storage
limit is 90 bytes and shipped-source ceiling 148000 bytes, deliberately lower
than their initial limits. Durable adapter ceilings use its three pressure
samples times 1.15. Minimum cooker iterations: 10; 12 have run, including
failed proves summarized in delivery_iterations.json. Final gates are separate.

Retention under benchmarks/: keep ceilings, the iteration summary, final memory
and durable gates, the process probe result, and the audit findings list. Write
calibration, baseline, stress, prove, and other episode intermediates to
benchmarks/output/ (gitignored). Do not promote raw per-iteration samples into
tracked paths once the episode stops.

Results identify the base revision, uncommitted worktree, source/probe hashes,
start/end UTC times, machine class, raw samples, maxima and failing series.
Earlier partial implementation samples predate the source-hash additions and
are identified by iteration/change plus their observed shipped source size.
No base-repository or cross-machine speed improvement is claimed.

Stop: final gates green after the recorded repairs; no high-confidence
first-party candidate for this fixture remains. PostgreSQL, host cache backends,
long-duration retention and real host callbacks require host-specific runs.
