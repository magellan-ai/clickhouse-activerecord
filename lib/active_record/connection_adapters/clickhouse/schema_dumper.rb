# frozen_string_literal: true

require "active_record/connection_adapters/abstract/schema_dumper"

module ActiveRecord
  module ConnectionAdapters
    module Clickhouse
      class SchemaDumper < ConnectionAdapters::SchemaDumper
        class << self
          def dump(connection = ActiveRecord::Base.connection, stream = STDOUT, config = ActiveRecord::Base, default = false)
            dumper = connection.create_schema_dumper(generate_options(config))
            dumper.simple = default
            dumper.dump(stream)
            stream
          end
        end

        attr_accessor :simple

        private

        def header(stream)
          stream.puts <<HEADER
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# #{simple ? 'db' : 'clickhouse'}:schema:load`. When creating a new database, `rails #{simple ? 'db' : 'clickhouse'}:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

#{simple ? 'ActiveRecord' : 'ClickhouseActiverecord'}::Schema.define(#{define_params}) do
HEADER
        end

        def tables(stream)
          functions = @connection.functions.sort
          functions.each do |function|
            function(function, stream)
          end

          sorted_tables =
            @connection.tables.sort do |a, b|
              @connection.show_create_table(a).match(/^CREATE\s+(MATERIALIZED\s+)?VIEW/) ? 1 : a <=> b
            end
          sorted_tables.each do |table_name|
            table(table_name, stream) unless ignored?(table_name)
          end
        end

        def table(table, stream)
          if table.match(/^\.inner/).nil?
            unless simple
              stream.puts "  # TABLE: #{table}"
              sql = @connection.show_create_table(table)
              stream.puts "  # SQL: #{sql.gsub(/ENGINE = Replicated(.*?)\('[^']+',\s*'[^']+',?\s?([^\)]*)?\)/, "ENGINE = \\1(\\2)")}" if sql
              # super(table.gsub(/^\.inner\./, ''), stream)

              # detect view table
              match = sql.match(/^CREATE\s+(MATERIALIZED\s+)?VIEW/)
            end

            # Copy from original dumper
            columns = @connection.columns(table)
            begin
              self.table_name = table

              tbl = StringIO.new

              # first dump primary key column
              pk = @connection.primary_key(table)

              tbl.print "  create_table #{remove_prefix_and_suffix(table).inspect}"

              unless simple
                # Add materialize flag
                tbl.print ', view: true' if match
                tbl.print ', materialized: true' if match && match[1].presence
              end

              case pk
              when String
                tbl.print ", primary_key: #{pk.inspect}" unless pk == "id"
                pkcol = columns.detect { |c| c.name == pk }
                pkcolspec = column_spec_for_primary_key(pkcol)
                tbl.print ", #{format_colspec(pkcolspec)}" if pkcolspec.present?
              when Array
                tbl.print ", primary_key: #{pk.inspect}"
              else
                tbl.print ", id: false"
              end

              unless simple
                table_options = @connection.table_options(table)
                if table_options.present?
                  tbl.print ", #{format_options(table_options)}"
                end
              end

              tbl.puts ", force: :cascade do |t|"

              # then dump all non-primary key columns
              if simple || !match
                columns.each do |column|
                  raise StandardError, "Unknown type '#{column.sql_type}' for column '#{column.name}'" unless @connection.valid_type?(column.type)
                  next if column.name == pk
                  type, colspec = column_spec(column)
                  if type.is_a?(Symbol)
                    tbl.print "    t.#{type} #{column.name.inspect}"
                  else
                    tbl.print "    t.column #{column.name.inspect}, #{type.inspect}"
                  end
                  tbl.print ", #{format_colspec(colspec)}" if colspec.present?
                  tbl.puts
                end
              end

              indexes_in_create(table, tbl)
              check_constraints_in_create(table, tbl) if @connection.supports_check_constraints?

              tbl.puts "  end"
              tbl.puts

              tbl.rewind
              stream.print tbl.read
            rescue => e
              stream.puts "# Could not dump table #{table.inspect} because of following #{e.class}"
              stream.puts "#   #{e.message}"
              stream.puts
            ensure
              self.table_name = nil
            end
          end
        end

        def function(function, stream)
          stream.puts "  # FUNCTION: #{function}"
          sql = @connection.show_create_function(function)
          return unless sql

          stream.puts "  # SQL: #{sql}"
          stream.puts "  create_function \"#{function}\", \"#{sql.sub(/\ACREATE( OR REPLACE)? FUNCTION .*? AS/, '').strip}\", force: true"
          stream.puts
        end

        def format_options(options)
          if options && options[:options]
            options[:options] = options[:options].gsub(/^Replicated(.*?)\('[^']+',\s*'[^']+',?\s?([^\)]*)?\)/, "\\1(\\2)")
          end
          super
        end

        def format_colspec(colspec)
          if simple
            super.gsub(/CAST\('?([^,']*)'?,\s?'.*?'\)/, "\\1")
          else
            super
          end
        end

        def schema_limit(column)
          return nil if column.type == :float
          super
        end

        def schema_unsigned(column)
          return nil unless column.type == :integer && !simple
          (column.sql_type =~ /(Nullable)?\(?UInt\d+\)?/).nil? ? false : nil
        end

        def schema_array(column)
          (column.sql_type =~ /Array?\(/).nil? ? nil : true
        end

        def prepare_column_options(column)
          spec = {}
          spec[:unsigned] = schema_unsigned(column)
          spec[:array] = schema_array(column)
          spec.merge(super).compact
        end
      end
    end
  end
end
