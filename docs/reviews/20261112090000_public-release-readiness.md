# Public release readiness - onni

## Participants

Andrei Makarov (@amkisko)

## Decisions

Verdict: not ready for public release (repos stay private; no commit yet). Release prep advanced: lint green, dated CHANGELOG, appraisal locks, Rails/ActiveAdmin/AR request specs, pressure PASS. Remaining forge blockers: empty git history and private visibility (intentional until you open them).

Ready (present):

- RubyGems name `onni` is free (API 404).
- `gem build` succeeds; package includes lib, app (admin/models/views), generators, sig, community docs, LICENSE.
- No private-product strings found in packaged README/lib/app/docs examples after scrub.
- README states Onni is for flags / A/B / stats - not authorization.
- Community docs: LICENSE, SECURITY, CONTRIBUTING, CODE_OF_CONDUCT, GOVERNANCE.
- gemspec: `allowed_push_host` rubygems.org, MFA required metadata, ActiveSupport-only runtime dep.
- Specs: unit + `spec/dummy` request coverage for ActiveRecord adapter and ActiveAdmin Features page (21 examples green).
- Pressure L1 gate: PASS (`benchmarks/ceilings.json`).
- Engine Zeitwerk ignore for `app/admin`; prior-library migrator skips unsupported gates; Features page actions gated by `admin_authorized`.

Blockers (must clear before public cut):

- High: no commits; GitHub default branch empty. Evidence: `git status` "No commits yet"; `gh` `defaultBranchRef.name` empty.
- High: repository is private. Evidence: `gh repo view` `visibility: PRIVATE`.
- Medium: working tree fully untracked; cannot satisfy release clean-tree check. Evidence: `release.rb` git porcelain gate.

Should before / with first public 0.1.0:

- Commit, push `main`, open or keep public visibility intentionally.
- Confirm `admin_authorized` default allow-all stays documented as host must-set for production.
- Run full `bundle exec appraisal` matrix against committed locks.

Non-blockers for a first 0.x:

- Pressure not in GHA (harness + episode docs exist).
- Thin RBS vs full public API.
- Stats AR upsert race (best-effort; documented in engineering audit).

## Effects

- Attempting `make release` today fails before push: dirty/untracked tree, Unreleased changelog, lint, missing reproducible appraisal locks.
- Publishing while the GitHub repo is empty/private would strand consumers on a RubyGems tarball with a broken homepage/source link story.

## Next

1. First commit + push; set repo visibility for the intended public story.
2. Re-run pressure gate after any hot-path fix; then `make release`.

## Source

- `usr/bin/release.rb`, `usr/lib/release_version_check.rb`
- `CHANGELOG.md`, `onni.gemspec`, `README.md`
- `gh repo view amkisko/onni.rb`
- Peer: `activeadmin-device_authorization.rb` (dated CHANGELOG, locks, published history)
- `docs/issues/20261112085000_support-gaps-vs-peers.md`
