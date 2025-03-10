# frozen_string_literal: true

module ClickhouseActiverecord
  class Tasks
    delegate :connection, :establish_connection, to: ActiveRecord::Base

    def initialize(configuration)
      @configuration = configuration
    end

    def create
      establish_master_connection
      connection.create_database @configuration[:database]

      connection.schema_migration.create_table
      connection.internal_metadata.create_table
    rescue ActiveRecord::StatementInvalid => e
      if e.cause.to_s.include?('already exists')
        raise ActiveRecord::DatabaseAlreadyExists
      else
        raise
      end
    end

    def drop
      establish_master_connection
      connection.drop_database @configuration[:database]
    end

    def purge
      clear_active_connections!
      drop
      create
    end

    def structure_dump(path, *)
      establish_master_connection

      functions = connection.execute("SELECT create_query FROM system.functions WHERE origin = 'SQLUserDefined' ORDER BY name")['data']
                    .flatten
                    .map { |function| function.gsub('\\n', "\n") }
      table_defs = connection.execute("SHOW TABLES FROM #{@configuration[:database]}")['data']
                     .flatten
                     .reject { |name| /\.inner/.match?(name) || %w[schema_migrations ar_internal_metadata].include?(name) }
                     .map { |name| connection.show_create_table(name, single_line: false).gsub("#{@configuration[:database]}.", '') }
      views, tables = table_defs.partition { |sql| sql.match(/^CREATE\s+(MATERIALIZED\s+)?VIEW/) }
      definitions = functions.sort + tables.sort + views.sort

      File.open(path, 'w:utf-8') do |file|
        definitions.each do |sql|
          file.puts "#{sql};\n\n"
        end
      end
    end

    def structure_load(path, *)
      File.read(path)
          .split(";\n\n")
          .compact_blank
          .each do |sql|
        connection.execute(sql)
      end
    end

    def migrate
      check_target_version

      verbose = ENV["VERBOSE"] ? ENV["VERBOSE"] != "false" : true
      scope = ENV["SCOPE"]
      verbose_was, ActiveRecord::Migration.verbose = ActiveRecord::Migration.verbose, verbose
      connection.migration_context.migrate(target_version) do |migration|
        scope.blank? || scope == migration.scope
      end
      ActiveRecord::Base.clear_cache!
    ensure
      ActiveRecord::Migration.verbose = verbose_was
    end

    def clear_active_connections!
      if ActiveRecord::Base.respond_to?(:connection_handler)
        ActiveRecord::Base.connection_handler.clear_active_connections!
      else
        ActiveRecord::Base.clear_active_connections!
      end
    end

    private

    def establish_master_connection
      establish_connection @configuration
    end

    def check_target_version
      if target_version && !(ActiveRecord::Migration::MigrationFilenameRegexp.match?(ENV["VERSION"]) || /\A\d+\z/.match?(ENV["VERSION"]))
        raise "Invalid format of target version: `VERSION=#{ENV['VERSION']}`"
      end
    end

    def target_version
      ENV["VERSION"].to_i if ENV["VERSION"] && !ENV["VERSION"].empty?
    end
  end
end
