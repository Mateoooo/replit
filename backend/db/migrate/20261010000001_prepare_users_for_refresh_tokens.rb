class PrepareUsersForRefreshTokens < ActiveRecord::Migration[7.1]
  def up
    execute "UPDATE users SET email = LOWER(TRIM(email))"
    remove_column :users, :refresh_token if column_exists?(:users, :refresh_token)
    remove_index :users, :email if index_exists?(:users, :email)
    add_index :users, :email, unique: true
  end

  def down
    add_column :users, :refresh_token, :string unless column_exists?(:users, :refresh_token)
  end
end
