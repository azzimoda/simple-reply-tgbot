# frozen_string_literal: true

require 'active_record'
require 'fileutils'

DB_FILE = 'database.db'

ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: DB_FILE
)

ActiveRecord::Schema.define do
  create_table :users, if_not_exists: true do |t|
    t.integer :tg_user_id, null: false
    t.string :state, null: true
    t.string :key_to_add, null: true
    t.timestamps
  end
  add_index :users, :tg_user_id, if_not_exists: true, unique: true

  create_table :commands, if_not_exists: true do |t|
    t.references :user, null: false, foreign_key: true
    t.string :key, null: false
    t.string :response_kind, null: false
    t.string :response_data, null: false
    t.timestamps
  end
  add_index :commands, :user_id, if_not_exists: true
  add_index :commands, :key, if_not_exists: true
end

# Require all models
MODELS_DIR = File.expand_path('./models/*.rb', __dir__).freeze
Dir[MODELS_DIR].each { require it }
