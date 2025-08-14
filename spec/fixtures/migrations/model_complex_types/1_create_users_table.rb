# frozen_string_literal: true

class CreateUsersTable < ActiveRecord::Migration[7.1]
  def up
    create_table :users, options: 'MergeTree ORDER BY id', force: true do |t|
      t.integer :id, null: false
      t.column :tuple_with_arrays, 'Tuple(names Array(String), birthday Date)', null: false
      t.column :array_of_tuples, 'Array(Tuple(name String, num_pets UInt64))', null: false
    end
  end
end
