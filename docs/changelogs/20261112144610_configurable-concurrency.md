# Configurable concurrency for threads and fibers

## Participants

Andrei Makarov (@amkisko)

## Decisions

Expose `config.concurrency` as `:mutex` (default) or `:none`. Use process Mutex locks for Group, Registry, and the memory adapter. Rely on Ruby 3.4+ fiber-aware Mutex ownership for cooperative fibers; document no Fiber.yield inside critical sections.

## Effects

- `Onni::Sync` with bootstrap-safe shared lock and per-adapter `new_lock`
- Group / Registry / Memory serialize shared in-process state under `:mutex`
- Specs: `sync_spec`, `group_concurrency_spec`
- README Concurrency section; initializer template sets `:mutex`
- `bundle exec rspec`: 77 examples, 0 failures

## Source

- `lib/onni/sync.rb`
- `lib/onni/configuration.rb`
