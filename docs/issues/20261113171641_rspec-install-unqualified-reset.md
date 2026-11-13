# Fix Onni::RSpec.install! unqualified reset!

## Participants

Andrei

## Decisions

Ship a patch that qualifies `Onni::RSpec.reset!` inside the RSpec before hook registered by `install!`. Keep the public `install!` / `reset!` names. Prove the contract with an `instance_exec` example, not a stubbed `block.call`.

## Effects

- Implemented and covered in this tree (see dependency and changelog notes).
- Published gem 1.0.1 still has the broken unqualified hook until a newer cut.

## Next

- Included in 2.0.0 cut; deliver with `make release`.
- Hosts on 1.0.1 keep the manual `config.before { Onni::RSpec.reset! }` workaround until they upgrade.

## Source

- `docs/dependencies/20261113171641_onni-rspec-install-unqualified-reset.md`
- `docs/changelogs/20261113171641_rspec-install-qualify-reset.md`
- `docs/reviews/20261113171641_rspec-install-audit.md`
