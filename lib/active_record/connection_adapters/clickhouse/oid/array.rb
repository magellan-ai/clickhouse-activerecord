# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Clickhouse
      module OID # :nodoc:
        class Array < Type::Value # :nodoc:

          def self.parse_subtype(sql_type)
            type_tree = Subtypes::SchemaParser.new.parse(sql_type)
            Subtypes::SchemaNode.new(type_tree)
                                .arg_list
                                .first
                                .type_expression
          end

          delegate :type, to: :@subtype, allow_nil: true

          def initialize(subtype)
            @subtype = subtype
          end

          def deserialize(value)
            return value.map { |item| deserialize(item) } if value.is_a?(::Array)
            return value if value.nil?

            @subtype.deserialize(value)
          end

          def serialize(value)
            return value.map { |item| serialize(item) } if value.is_a?(::Array)
            return value if value.nil?

            @subtype.serialize(value)
          end

        end
      end
    end
  end
end
