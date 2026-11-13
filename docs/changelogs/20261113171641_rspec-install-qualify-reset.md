# Qualify Onni::RSpec.install! reset hook

## Participants

Andrei

## Decisions

Qualify `Onni::RSpec.install!` so the before hook calls `Onni::RSpec.reset!`. RSpec `instance_exec` must not resolve bare `reset!` on the example. Replace the stub-only install spec with an `instance_exec` contract.

## Effects

- `lib/onni/rspec.rb`: hook body is `Onni::RSpec.reset!`.
- `spec/onni/rspec_helper_spec.rb`: registers via `install!`, runs the proc with `instance_exec`, expects memory adapter.
- Before fix the same example raised `NoMethodError: undefined method 'reset!'`. After fix focused and full suite green (2/2 and 249/249).

## Next

- Include in the next patch cut so hosts on 1.0.1 can drop the manual before workaround.

## Source

- `docs/dependencies/20261113171641_onni-rspec-install-unqualified-reset.md`
- `docs/reviews/20261113171641_rspec-install-audit.md`
