class CreateLogEntries < ActiveRecord::Migration[7.1]
  def change
    create_table :log_entries do |t|
      t.references :run, null: false, foreign_key: true
      t.string   :stream,    null: false, default: "stdout"
      t.text     :content,   null: false, default: ""
      t.datetime :logged_at, null: false, precision: 6
    end
    add_index :log_entries, %i[run_id logged_at]
  end
end
