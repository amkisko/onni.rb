# Rails 7.2 SQLite boolean default introspection

## Participants

Andrei Makarov.

## Dependency

ActiveRecord 7.2.4 from gemfiles/rails72.gemfile.lock, using SQLite. Comparison:
ActiveRecord 8.1.4.1 from the root lockfile. This is compatibility-fixture work,
not a change to the host framework requirements.

## Symptom

The first local Rails 7.2 agent test reused the database previously created by
Rails 8.1. It failed creating AdminUser because ActiveRecord read a NOT NULL
boolean DEFAULT TRUE as a nil model default. The same issue affects DEFAULT
FALSE. It is a default-introspection compatibility defect, not a GraphQL
permission failure.

## Evidence

- BUNDLE_IGNORE_CONFIG=1 BUNDLE_GEMFILE=gemfiles/rails72.gemfile bundle exec ruby usr/scripts/check_sqlite_boolean_defaults.rb
  -> ActiveRecord 7.2.4: TRUE and FALSE produce nil column/model defaults;
     numeric 1 and 0 produce true/false model defaults.
- BUNDLE_IGNORE_CONFIG=1 bundle exec ruby usr/scripts/check_sqlite_boolean_defaults.rb
  -> ActiveRecord 8.1.4.1: all four forms produce the expected boolean values.
- BUNDLE_IGNORE_CONFIG=1 BUNDLE_GEMFILE=gemfiles/rails72.gemfile POLYRUN_SHARD_INDEX=72 bundle exec rspec spec/requests/agent_graphql*_spec.rb
  -> 32 examples, 0 failures with a fresh framework-isolated test database.

The reproduction creates only a disposable SQLite file. No production database
was read or modified. The ordinary test fixture already supports an independent
file through POLYRUN_SHARD_INDEX; no package monkey patch was added.

## Suggested fix

Keep local appraisal fixtures isolated so an older adapter does not inherit a
newer adapter's generated schema. If a real host must read this literal schema
on 7.2, assess compatible numeric boolean defaults or an upstream adapter fix.
The observed reproduction supports that workaround; it does not establish a
safe downgrade for an arbitrary application database.

## Next

The requested integration runs on the isolated 7.2 fixture. An upstream report
or framework patch can be handled separately; none was sent from this task.

## Source

- [Adapter source](https://github.com/rails/rails/blob/v7.2.4/activerecord/lib/active_record/connection_adapters/sqlite3/schema_statements.rb)
- usr/scripts/check_sqlite_boolean_defaults.rb
- spec/dummy/config/database.yml
