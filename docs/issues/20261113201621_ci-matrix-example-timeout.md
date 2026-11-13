# CI test jobs fail on audience filter matrix example timeout

## Participants

Andrei Makarov (@amkisko).

## Decisions

- Treat polyrun's default 30s per-example timeout as the CI failure mode for
  `audience_filter_matrix_spec` (11250-row examples take ~3-5s locally and can
  exceed 30s on GitHub-hosted runners).
- Slice matrix rows into 1500-row examples so each stays under the default budget.
- Set `RSPEC_EXAMPLE_TIMEOUT_SEC=120` on test and coverage jobs as runner margin.

## Effects

- Reproduced with `RSPEC_EXAMPLE_TIMEOUT_SEC=3` against the unsliced matrix:
  8 failures, all `Timeout::ExitException` / `execution expired` inside the
  11250-row examples.
- After slicing to 1500 rows: same `RSPEC_EXAMPLE_TIMEOUT_SEC=3` run is
  165 examples, 0 failures; slowest slice ~0.65s locally.
- `BUNDLE_GEMFILE=gemfiles/rails8ruby34.gemfile` and `rails72.gemfile`
  `polyrun parallel-rspec --workers 5 --merge-failures`: both exit 0.
- Workflow test/coverage jobs set `RSPEC_EXAMPLE_TIMEOUT_SEC=120`.

## Next

1. Commit/push the branch and confirm GitHub Actions test jobs on main or PR.
2. Refresh local `gh` auth so failed-run logs are readable without HTML scraping.

## Source

- `.github/workflows/test.yml`
- `spec/onni/audience_filter_matrix_spec.rb`
- https://github.com/amkisko/onni.rb/actions/runs/43496150024
