# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_02_08_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "idempotency_keys", force: :cascade do |t|
    t.string "key", null: false
    t.bigint "order_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_idempotency_keys_on_key", unique: true
    t.index ["order_id"], name: "index_idempotency_keys_on_order_id"
  end

  create_table "orders", force: :cascade do |t|
    t.integer "customer_id", null: false
    t.string "product_name", null: false
    t.integer "quantity", default: 0, null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_orders_on_customer_id"
    t.index ["product_name"], name: "index_orders_on_product_name", unique: true
    t.index ["status"], name: "index_orders_on_status"
  end

  create_table "outbox_events", force: :cascade do |t|
    t.string "aggregate_type", null: false
    t.string "aggregate_id", null: false
    t.string "event_type", null: false
    t.jsonb "payload", default: {}, null: false
    t.integer "status", default: 0, null: false
    t.datetime "processed_at"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status", "created_at"], name: "index_outbox_events_on_status_and_created_at"
    t.index ["status"], name: "index_outbox_events_on_status"
  end

  add_foreign_key "idempotency_keys", "orders"
end
