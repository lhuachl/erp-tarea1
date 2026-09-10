class CreateClients < ActiveRecord::Migration[8.1]
  def change
    create_table :clients do |t|
      t.string :nombre, null: false
      t.string :telefono
      t.string :email
      t.string :direccion
      t.string :notas

      t.timestamps
    end
    add_index :clients, %i[nombre telefono], unique: true
  end
end
