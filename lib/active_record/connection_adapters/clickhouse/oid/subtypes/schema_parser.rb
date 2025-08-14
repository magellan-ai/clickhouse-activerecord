# frozen_string_literal: true

require 'active_record/connection_adapters/clickhouse/oid/subtypes/schema_node'

require 'parslet'

module ActiveRecord
  module ConnectionAdapters
    module Clickhouse
      module OID # :nodoc:
        class Subtypes # :nodoc:
          class SchemaParser < Parslet::Parser # :nodoc:

            rule(:space) { match('\s').repeat(1) }
            rule(:space?) { space.maybe }

            rule(:backtick) { str('`') }
            rule(:quote) { str('"') }
            rule(:lparen) { str('(') >> space? }
            rule(:rparen) { str(')') >> space? }
            rule(:comma) { str(',') >> space? }

            rule(:string) { match('\w').repeat(1) }
            rule(:integer) { match('\d').repeat(1).as(:int) >> space? }

            rule(:unquoted_name) { string.as(:name) }
            rule(:double_quoted_name) { quote >> string.as(:name) >> quote }
            rule(:backtick_quoted_name) { backtick >> string.as(:name) >> backtick }
            rule(:name) { unquoted_name | double_quoted_name | backtick_quoted_name }

            rule(:type) { string.as(:type) }
            rule(:named_field) { name >> space >> type_def >> space? }

            rule(:arg) { integer | named_field | type_def }
            rule(:arg_list) { arg >> (comma >> arg).repeat }
            rule(:arg_expr) { lparen >> arg_list.as(:arg_list) >> rparen }

            rule(:type_def) { type >> arg_expr.maybe }

            root :type_def

          end
        end
      end
    end
  end
end
