# frozen_string_literal: true

class CreateUsersTable < ActiveRecord::Migration[7.1]
  def up
    create_table :users, options: 'MergeTree ORDER BY id', force: true do |t|
      t.integer :id, null: false
      t.column :data, 'Tuple(name String, num_pets UInt8, birthday Date)', null: false
    end
  end
end
