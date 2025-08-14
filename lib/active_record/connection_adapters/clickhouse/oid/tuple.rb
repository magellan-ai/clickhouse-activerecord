# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Clickhouse
      module OID # :nodoc:
        class Tuple < Type::Value # :nodoc:

          attr_reader :schema_hash

          def self.parse_schema(sql_type)
            type_tree = Subtypes::SchemaParser.new.parse(sql_type)
            elements = Subtypes::SchemaNode.new(type_tree).arg_list
            elements.each_with_index.to_h { |el, i| [(el.name.presence || i), el.type_expression] }
          end

          def initialize(schema_hash)
            @schema_hash = schema_hash.with_indifferent_access
            @container_class = Struct.new(*@schema_hash.keys.map(&:to_sym))
          end

          def type
            :tuple
          end

          def cast(value)
            return nil if value.nil?
            return value if value.is_a?(@container_class)

            value = schema_hash.keys.zip(value).to_h if value.is_a?(::Array)
            value = value.with_indifferent_access
            after_cast = schema_hash.map { |k, type| type.cast(value[k]) }
            @container_class.new(*after_cast)
          end

          def serialize(value)
            return nil if value.nil?

            case value
            when @container_class
              value
            when Hash
              indifferent_access_value = value.with_indifferent_access
              @container_class.new(*schema_hash.map { |k, type| type.serialize(indifferent_access_value[k]) })
            else
              @container_class.new(*value)
            end
          end

          def ==(other)
            super && schema_hash == other.schema_hash
          end

        end
      end
    end
  end
end
