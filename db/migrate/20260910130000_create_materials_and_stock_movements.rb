class CreateMaterialsAndStockMovements < ActiveRecord::Migration[8.1]
  def change
    create_table :materials do |t|
      t.string :nombre, null: false
      t.string :unidad, null: false
      t.decimal :stock_actual, null: false, default: 0
      t.decimal :stock_min, null: false, default: 0
      t.decimal :costo_unitario, null: false, default: 0

      t.timestamps
    end
    add_index :materials, :nombre, unique: true

    create_table :stock_movements do |t|
      t.references :material, null: false, foreign_key: true
      t.string :tipo, null: false
      t.decimal :cantidad, null: false
      t.string :referencia
      t.date :fecha, null: false, default: -> { "CURRENT_DATE" }

      t.timestamps
    end
  end
end
