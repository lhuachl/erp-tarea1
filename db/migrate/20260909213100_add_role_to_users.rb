class AddRoleToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :role, :string, null: false, default: "operador"
    add_index :users, :role
  end
end
