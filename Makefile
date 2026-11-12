.PHONY: release lint audit test clean bench-calibrate bench-matrix bench-gate

bench-calibrate:
	SCENARIO=calibrate bundle exec ruby benchmarks/load.rb

bench-matrix:
	SCENARIO=matrix bundle exec ruby benchmarks/load.rb

bench-gate:
	SCENARIO=gate bundle exec ruby benchmarks/load.rb


release:
	ruby usr/bin/release.rb

lint:
	bundle exec rubocop
	bundle exec rbs validate
	ruby usr/bin/check_locale_parity.rb
	ruby usr/bin/check_loc.rb

audit:
	@for lock in Gemfile.lock gemfiles/*.gemfile.lock; do \
		if [ "$${lock}" = "gemfiles/rails72.gemfile.lock" ]; then \
			echo "==> $${lock} (skip: Rails 7.2 has no published fix yet; document in docs/dependencies if needed)"; \
			continue; \
		fi; \
		echo "==> $${lock}"; \
		bundle exec bundler-audit check --gemfile-lock "$${lock}" || exit 1; \
	done

test: lint
	bundle exec polyrun parallel-rspec --workers 5 --merge-failures

clean:
	rm -rf coverage .pray/cache tmp
	rm -f spec/examples.txt *.gem
