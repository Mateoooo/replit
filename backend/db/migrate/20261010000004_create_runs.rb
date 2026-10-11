class CreateRuns < ActiveRecord::Migration[7.1]
  def change
    create_table :runs do |t|
      t.references :project, null: false, foreign_key: true
      t.string   :status, null: false, default: "pending"
      t.string   :container_id
      t.string   :image_tag
      t.datetime :started_at
      t.datetime :finished_at
      t.integer  :exit_code
      t.text     :error_message
      t.timestamps
    end
    add_index :runs, %i[project_id created_at]
    # Не больше одного активного запуска на проект — гарантия на уровне БД
    add_index :runs, :project_id, unique: true,
              where: "status IN ('pending', 'running')",
              name: "index_runs_one_active_per_project"
  end
end
