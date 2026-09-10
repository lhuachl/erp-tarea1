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

ActiveRecord::Schema[8.1].define(version: 2026_09_10_140000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "extensions.pg_stat_statements"
  enable_extension "extensions.pgcrypto"
  enable_extension "extensions.uuid-ossp"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vault.supabase_vault"

  create_table "backlog_items", force: :cascade do |t|
    t.integer "cod_duration", default: 0, null: false
    t.integer "cod_risk_reduction", default: 0, null: false
    t.integer "cod_time_criticality", default: 0, null: false
    t.integer "cod_value", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "descripcion", default: "", null: false
    t.string "estado", default: "backlog", null: false
    t.string "prioridad", default: "media", null: false
    t.bigint "sprint_id"
    t.integer "story_points", null: false
    t.string "titulo", null: false
    t.datetime "updated_at", null: false
    t.index ["sprint_id"], name: "index_backlog_items_on_sprint_id"
  end

  create_table "clients", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "direccion"
    t.string "email"
    t.string "nombre", null: false
    t.string "notas"
    t.string "telefono"
    t.datetime "updated_at", null: false
    t.index ["nombre", "telefono"], name: "index_clients_on_nombre_and_telefono", unique: true
  end

  create_table "daily_snapshots", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "fecha", null: false
    t.integer "horas_restantes", null: false
    t.integer "puntos_restantes", null: false
    t.bigint "sprint_id", null: false
    t.datetime "updated_at", null: false
    t.index ["sprint_id", "fecha"], name: "index_daily_snapshots_on_sprint_id_and_fecha", unique: true
    t.index ["sprint_id"], name: "index_daily_snapshots_on_sprint_id"
  end

  create_table "materials", force: :cascade do |t|
    t.decimal "costo_unitario", default: "0.0", null: false
    t.datetime "created_at", null: false
    t.string "nombre", null: false
    t.decimal "stock_actual", default: "0.0", null: false
    t.decimal "stock_min", default: "0.0", null: false
    t.string "unidad", null: false
    t.datetime "updated_at", null: false
    t.index ["nombre"], name: "index_materials_on_nombre", unique: true
  end

  create_table "sprints", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "estado", default: "planning", null: false
    t.date "fecha_fin", null: false
    t.date "fecha_inicio", null: false
    t.string "nombre", null: false
    t.string "objetivo", default: "", null: false
    t.datetime "updated_at", null: false
  end

  create_table "stock_movements", force: :cascade do |t|
    t.decimal "cantidad", null: false
    t.datetime "created_at", null: false
    t.date "fecha", default: -> { "CURRENT_DATE" }, null: false
    t.bigint "material_id", null: false
    t.string "referencia"
    t.string "tipo", null: false
    t.datetime "updated_at", null: false
    t.index ["material_id"], name: "index_stock_movements_on_material_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role", default: "operador", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "backlog_items", "sprints"
  add_foreign_key "daily_snapshots", "sprints"
  add_foreign_key "stock_movements", "materials"
end
