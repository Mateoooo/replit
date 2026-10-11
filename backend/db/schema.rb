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

ActiveRecord::Schema[8.0].define(version: 2026_10_10_000007) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "command_executions", force: :cascade do |t|
    t.bigint "run_id", null: false
    t.bigint "user_id", null: false
    t.text "command", null: false
    t.text "output", default: "", null: false
    t.integer "exit_code"
    t.string "status", default: "pending", null: false
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["run_id"], name: "index_command_executions_on_run_id"
    t.index ["user_id"], name: "index_command_executions_on_user_id"
  end

  create_table "log_entries", force: :cascade do |t|
    t.bigint "run_id", null: false
    t.string "stream", default: "stdout", null: false
    t.text "content", default: "", null: false
    t.datetime "logged_at", null: false
    t.index ["run_id", "logged_at"], name: "index_log_entries_on_run_id_and_logged_at"
    t.index ["run_id"], name: "index_log_entries_on_run_id"
  end

  create_table "projects", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.string "status", default: "created", null: false
    t.string "archive_path"
    t.string "archive_filename"
    t.bigint "archive_size"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "name"], name: "index_projects_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_projects_on_user_id"
  end

  create_table "refresh_tokens", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "revoked_at"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_refresh_tokens_on_expires_at"
    t.index ["token_digest"], name: "index_refresh_tokens_on_token_digest", unique: true
    t.index ["user_id"], name: "index_refresh_tokens_on_user_id"
  end

  create_table "runs", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.string "status", default: "pending", null: false
    t.string "container_id"
    t.string "image_tag"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.integer "exit_code"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "host_port"
    t.index ["project_id", "created_at"], name: "index_runs_on_project_id_and_created_at"
    t.index ["project_id"], name: "index_runs_on_project_id"
    t.index ["project_id"], name: "index_runs_one_active_per_project", unique: true, where: "((status)::text = ANY ((ARRAY['pending'::character varying, 'running'::character varying])::text[]))"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "command_executions", "runs"
  add_foreign_key "command_executions", "users"
  add_foreign_key "log_entries", "runs"
  add_foreign_key "projects", "users"
  add_foreign_key "refresh_tokens", "users"
  add_foreign_key "runs", "projects"
end
