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

ActiveRecord::Schema[8.1].define(version: 2026_08_24_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "ai_messages", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.string "role", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "created_at"], name: "index_ai_messages_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_ai_messages_on_user_id"
  end

  create_table "asset_contributions", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.date "occurred_on", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_asset_id", null: false
    t.index ["user_asset_id", "occurred_on"], name: "index_asset_contributions_on_user_asset_id_and_occurred_on"
    t.index ["user_asset_id"], name: "index_asset_contributions_on_user_asset_id"
  end

  create_table "asset_valuations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_asset_id", null: false
    t.integer "value_cents", null: false
    t.date "valued_on", null: false
    t.index ["user_asset_id", "valued_on"], name: "index_asset_valuations_on_user_asset_id_and_valued_on", unique: true
    t.index ["user_asset_id"], name: "index_asset_valuations_on_user_asset_id"
  end

  create_table "budget_items", force: :cascade do |t|
    t.integer "amount_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "frequency", default: "weekly", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.string "section", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "section", "name"], name: "index_budget_items_on_user_id_and_section_and_name", unique: true
    t.index ["user_id"], name: "index_budget_items_on_user_id"
  end

  create_table "user_assets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "depreciation_method", default: "none"
    t.decimal "depreciation_rate", precision: 5, scale: 2
    t.string "item_name", null: false
    t.date "purchase_date", null: false
    t.integer "purchase_price_cents", null: false
    t.string "purchase_price_currency", default: "AUD", null: false
    t.integer "salvage_value_cents", default: 0
    t.datetime "updated_at", null: false
    t.integer "useful_life_years"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_user_assets_on_user_id"
  end

  create_table "user_liabilities", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.string "amount_currency", default: "AUD", null: false
    t.datetime "created_at", null: false
    t.decimal "interest_rate", precision: 5, scale: 2, default: "0.0", null: false
    t.string "item_name", null: false
    t.integer "minimum_monthly_payment_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_user_liabilities_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.decimal "loan_tax_capital_growth", precision: 5, scale: 2
    t.decimal "loan_tax_dividend_yield", precision: 5, scale: 2
    t.decimal "loan_tax_franking_pct", precision: 5, scale: 2
    t.bigint "loan_tax_gross_salary_cents"
    t.boolean "loan_tax_has_hecs"
    t.bigint "loan_tax_hecs_balance_cents"
    t.decimal "loan_tax_interest_rate", precision: 5, scale: 2
    t.bigint "loan_tax_loan_amount_cents"
    t.string "loan_tax_loan_type"
    t.boolean "loan_tax_private_hospital_cover"
    t.integer "loan_tax_term_years"
    t.string "password_digest", null: false
    t.decimal "runway_annual_growth", precision: 5, scale: 2
    t.integer "runway_monthly_spend_cents"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "ai_messages", "users"
  add_foreign_key "asset_contributions", "user_assets"
  add_foreign_key "asset_valuations", "user_assets"
  add_foreign_key "budget_items", "users"
  add_foreign_key "user_assets", "users"
  add_foreign_key "user_liabilities", "users"
end
