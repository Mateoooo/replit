class CreateProjects < ActiveRecord::Migration[7.1]
  def change
    create_table :projects do |t|
      t.references :user, null: false, foreign_key: true
      t.string  :name,   null: false
      t.string  :status, null: false, default: "created"
      t.string  :archive_path
      t.string  :archive_filename
      t.bigint  :archive_size
      t.timestamps
    end
    add_index :projects, %i[user_id name], unique: true
  end
end
