# frozen_string_literal: true

namespace :clickhouse do
  task prepare_schema_migration_table: :environment do
    if ActiveRecord.version < Gem::Version.new('7.1')
      ActiveRecord::SchemaMigration.create_table unless ENV['simple'] || ARGV.any? { |a| a.include?('--simple') }
    else
      connection = ActiveRecord::Tasks::DatabaseTasks.migration_connection
      connection.schema_migration.create_table unless ENV['simple'] || ARGV.any? { |a| a.include?('--simple') }
    end
  end

  task prepare_internal_metadata_table: :environment do
    if ActiveRecord.version < Gem::Version.new('7.1')
      ActiveRecord::InternalMetadata.create_table unless ENV['simple'] || ARGV.any? { |a| a.include?('--simple') }
    else
      connection = ActiveRecord::Tasks::DatabaseTasks.migration_connection
      connection.internal_metadata.create_table unless ENV['simple'] || ARGV.any? { |a| a.include?('--simple') }
    end
  end

  namespace :schema do
    desc 'Load database schema'
    task load: %i[prepare_schema_migration_table prepare_internal_metadata_table] do
      warn 'Warning: `rake clickhouse:schema:load` is deprecated! Use `rake db:schema:load:clickhouse` instead', uplevel: 1
      simple = ENV['simple'] || ARGV.any? { |a| a.include?('--simple') } ? '_simple' : nil
      ActiveRecord::Tasks::DatabaseTasks.migration_connection
                                        .schema_migration
                                        .drop_table
      load(Rails.root.join("db/clickhouse_schema#{simple}.rb"))
    end

    desc 'Dump database schema'
    task dump: :environment do |_t, args|
      warn 'Warning: `rake clickhouse:schema:dump` is deprecated! Use `rake db:schema:dump:clickhouse` instead', uplevel: 1
      simple = ENV['simple'] || args[:simple] || ARGV.any? { |a| a.include?('--simple') } ? '_simple' : nil
      filename = Rails.root.join("db/clickhouse_schema#{simple}.rb")
      File.open(filename, 'w:utf-8') do |file|
        ActiveRecord::Base.establish_connection(:clickhouse)
        ClickhouseActiverecord::SchemaDumper.dump(ActiveRecord::Base.connection, file, ActiveRecord::Base, simple.present?)
      end
    end
  end

  namespace :structure do
    desc 'Load database structure'
    task load: 'db:check_protected_environments' do
      ClickhouseActiverecord::Tasks.new(current_db_config).structure_load(Rails.root.join('db/clickhouse_structure.sql'))
    end

    desc 'Dump database structure'
    task dump: 'db:check_protected_environments' do
      ClickhouseActiverecord::Tasks.new(current_db_config).structure_dump(Rails.root.join('db/clickhouse_structure.sql'))
    end
  end

  desc 'Creates the database from DATABASE_URL or config/database.yml'
  task :create do
    warn 'Warning: `rake clickhouse:create` is deprecated! Use `rake db:create:clickhouse` instead', uplevel: 1
    ActiveRecord::Tasks::DatabaseTasks.create current_db_config
  end

  desc 'Drops the database from DATABASE_URL or config/database.yml'
  task drop: 'db:check_protected_environments' do
    warn 'Warning: `rake clickhouse:drop` is deprecated! Use `rake db:drop:clickhouse` instead', uplevel: 1
    ActiveRecord::Tasks::DatabaseTasks.drop current_db_config
  end

  desc 'Empty the database from DATABASE_URL or config/database.yml'
  task purge: 'db:check_protected_environments' do
    warn 'Warning: `rake clickhouse:purge` is deprecated! Use `rake db:reset:clickhouse` instead', uplevel: 1
    ActiveRecord::Tasks::DatabaseTasks.purge current_db_config
  end

  # desc 'Resets your database using your migrations for the current environment'
  task :reset do
    warn 'Warning: `rake clickhouse:reset` is deprecated! Use `rake db:reset:clickhouse` instead', uplevel: 1
    Rake::Task['clickhouse:purge'].execute
    Rake::Task['clickhouse:migrate'].execute
  end

  desc 'Migrate the clickhouse database'
  task migrate: %i[prepare_schema_migration_table prepare_internal_metadata_table] do
    warn 'Warning: `rake clickhouse:migrate` is deprecated! Use `rake db:migrate:clickhouse` instead', uplevel: 1
    Rake::Task['db:migrate:clickhouse'].execute
    if File.exist? Rails.root.join('db/clickhouse_schema_simple.rb')
      Rake::Task['clickhouse:schema:dump'].execute(simple: true)
    end
  end

  desc 'Rollback the clickhouse database'
  task rollback: %i[prepare_schema_migration_table prepare_internal_metadata_table] do
    warn 'Warning: `rake clickhouse:rollback` is deprecated! Use `rake db:rollback:clickhouse` instead', uplevel: 1
    Rake::Task['db:rollback:clickhouse'].execute
    Rake::Task['clickhouse:schema:dump'].execute(simple: true) if File.exist?(Rails.root.join('db/clickhouse_schema_simple.rb'))
  end

  def current_db_config
    ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: 'clickhouse')
  end
end
