# Contributing Guidelines

## Automation authorship

You may use AI and automation tools. You remain the author of every line you submit: review, debug, and understand the change.

Keep pull requests small enough to review. Annotate non-obvious logic.

Never send project secrets or private context to public models.

## How to contribute

### Local checks and admin preview

Run `bundle install`, then `make admin-assets` before request specs or a browser
preview. The asset task needs Node.js 20 or newer and npm. It installs the locked
test-only Tailwind tools and builds ActiveAdmin's stylesheet from its installed
plugin plus the ActiveAdmin and Onni templates. Rails serves the generated CSS
and JavaScript from the dummy app's public directory. Rebuild after changing
view classes or updating ActiveAdmin. Generated assets are ignored by git and
are excluded from the gem.

Run `bundle exec rspec` for the suite and `make lint` for quality checks. CI builds
the same assets before request specs; `make test` includes the asset build.

System specs use a browser driver under the `:railsfi` name (Rails
`driven_by :playwright` would replace the registration and float Chromium).
After `make admin-assets`, install browsers once with
`./spec/dummy/node_modules/.bin/playwright-core install chromium` (the dummy app
pins `playwright-core` to the version expected by `playwright-ruby-client`).
When the CLI or Chromium install is missing, system examples skip with that
install hint.

### Reporting issues

Verify the facts before filing. Use issue templates for goals, constraints, and reproduction steps.

### Pull requests

Keep one pull request to one goal. Explain why the change is needed. Run smoke tests and regression checks locally before opening the request.

### Review

Reviewers will ask about approach and trade-offs. Treat suggested changes as part of the work.
