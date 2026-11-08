class AddWorkerColumnsToRuns < ActiveRecord::Migration[8.0]
  def change
    add_column :runs, :logs_cursor, :string      # метка времени последней сохранённой строки лога
    add_column :runs, :claimed_at, :datetime     # воркер «занял» запуск под сборку
    add_index :runs, :status
  end
end
