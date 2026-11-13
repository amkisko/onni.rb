.PHONY: release lint audit test admin-assets clean bench-calibrate bench-matrix bench-gate bench-stats-calibrate bench-stats-ladder bench-stats-gate

bench-calibrate:
	SCENARIO=calibrate bundle exec ruby benchmarks/load.rb

bench-matrix:
	SCENARIO=matrix bundle exec ruby benchmarks/load.rb

bench-gate:
	SCENARIO=gate bundle exec ruby benchmarks/load.rb

bench-stats-calibrate:
	SCENARIO=calibrate bundle exec ruby benchmarks/stats_write.rb

bench-stats-ladder:
	SCENARIO=ladder bundle exec ruby benchmarks/stats_write.rb

bench-stats-gate:
	SCENARIO=gate WRITERS_L1=8 OPS=200 bundle exec ruby benchmarks/stats_write.rb


release:
	ruby usr/bin/release.rb

lint:
	bundle exec rubocop
	bundle exec rbs validate
	ruby usr/bin/check_locale_parity.rb
	ruby usr/bin/check_loc.rb

audit:
	npm --prefix spec/dummy audit
	@for lock in Gemfile.lock gemfiles/*.gemfile.lock; do \
		if [ "$${lock}" = "gemfiles/rails72.gemfile.lock" ]; then \
			echo "==> $${lock} (skip: Rails 7.2 has no published fix yet; document in docs/dependencies if needed)"; \
			continue; \
		fi; \
		echo "==> $${lock}"; \
		bundle exec bundler-audit check --gemfile-lock "$${lock}" || exit 1; \
	done

test: lint admin-assets
	bundle exec polyrun parallel-rspec --workers 5 --merge-failures

admin-assets:
	npm --prefix spec/dummy ci
	bundle exec ruby usr/scripts/build_admin_assets.rb

clean:
	rm -rf coverage .pray/cache tmp
	rm -f spec/examples.txt *.gem
