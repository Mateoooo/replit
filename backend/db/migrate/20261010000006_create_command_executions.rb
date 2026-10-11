class CreateCommandExecutions < ActiveRecord::Migration[7.1]
  def change
    create_table :command_executions do |t|
      t.references :run,  null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text     :command, null: false
      t.text     :output,  null: false, default: ""
      t.integer  :exit_code
      t.string   :status, null: false, default: "pending"
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end
  end
end
