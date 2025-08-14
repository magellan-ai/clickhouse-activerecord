# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Clickhouse
      module OID # :nodoc:
        class Subtypes # :nodoc:
          class SchemaNode

            attr_reader :arg_list

            def initialize(tree)
              @name = tree[:name]
              @type = tree[:type]
              @arg_list = Array(tree[:arg_list]).map { |subtree| subtree.key?(:int) ? subtree[:int].to_i : SchemaNode.new(subtree) }
            end

            def name
              @name.to_s
            end

            def type
              @type.to_s
            end

            def type_expression
              "#{type}#{arguments}"
            end

            def to_s
              "#{quoted_name}#{type_expression}"
            end

            def name?
              name.present?
            end

            def arg_list?
              arg_list&.any?
            end

            private

            def quoted_name
              "\"#{name}\" " if name?
            end

            def arguments
              "(#{arg_list.map(&:to_s).join(', ')})" if arg_list?
            end

          end
        end
      end
    end
  end
end
