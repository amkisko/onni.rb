# Lockfile security bumps for graphql and puma

## Participants

Andrei Makarov.

## Decisions

Full dependency audit on 2026-11-23 found published advisories for graphql
2.6.15 and puma 8.1.1 on every Ruby lockfile. Raise graphql floor to
>= 2.6.16 and resolve puma to >= 8.1.2 across Gemfile.lock and appraisal
locks. Keep the Rails 7.2 compatibility lock as a known scan skip until that
line is patched or retired; do not treat the Makefile skip as a clean audit.

## Effects

- graphql floor and locks are 2.6.16; puma floor and locks are 8.1.2
- `make audit` -> exit 0; only rails72 remains an intentional skip
- `bundle exec rspec spec/requests/agent_graphql*.rb` -> 33 examples, 0 failures
- Assessment notes under docs/dependencies marked fixed for these bumps

## Next

- Revisit Rails 7.2 disposition in
  docs/dependencies/20261113120312_rails72-advisory-matches.md

## Source

- docs/dependencies/20261123163707_graphql-2616-security-advisories.md
- docs/dependencies/20261123163708_puma-812-security-advisories.md
- docs/dependencies/20261113120312_rails72-advisory-matches.md
