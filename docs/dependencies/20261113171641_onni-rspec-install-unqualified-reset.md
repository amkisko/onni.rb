# onni RSpec.install! unqualified reset!

## Participants

Andrei

## Dependency

onni (~> 1.0), lockfile onni (1.0.1). File: `lib/onni/rspec.rb`.

## Symptom

Every example fails in `before` with `NoMethodError: undefined method 'reset!'` on the example group when the host calls `Onni::RSpec.install!`. The suite cannot boot under that helper.

## Evidence

1. `Onni::RSpec.install!` registered `rspec_config.before { reset! }`. RSpec runs the block with `instance_exec` on the example, so `reset!` resolved as example `#reset!`, not `Onni::RSpec.reset!`.
2. Local reproduction: `Object.new.instance_exec` of the registered hook raised `NoMethodError: undefined method 'reset!'` with backtrace at `lib/onni/rspec.rb` in `install!`.
3. Prior helper spec called the hook with `block.call` and only stubbed `receive(:reset!)`, so it never exercised `instance_exec` and stayed green while hosts failed.
4. Host testimony: focused Onni specs after adopting `install!` reported many failures of this shape (count not re-run here).

## Suggested fix

Upstream: qualify the hook as `before { Onni::RSpec.reset! }` (or capture `method(:reset!)`). Host workaround until upgrade: `config.before { Onni::RSpec.reset! }` instead of `Onni::RSpec.install!`.

## Effects

- Fixed in this tree: `lib/onni/rspec.rb` uses `Onni::RSpec.reset!` inside the hook.
- Spec `spec/onni/rspec_helper_spec.rb` runs the registered hook via `instance_exec` on a plain object and asserts no error plus memory adapter reset.
- Focused and full suite: `bundle exec rspec spec/onni/rspec_helper_spec.rb` 2 examples, 0 failures; `bundle exec rspec` 249 examples, 0 failures.

## Next

- Publish a patch release that includes the qualified hook.
- Hosts drop the manual `config.before { Onni::RSpec.reset! }` workaround after upgrading past that release.

## Source

- `lib/onni/rspec.rb` (`install!`)
- `spec/onni/rspec_helper_spec.rb`
- https://rubygems.org/gems/onni/versions/1.0.1
