class CreateSprintsAndDailySnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :sprints do |t|
      t.string :nombre, null: false
      t.string :objetivo, default: "", null: false
      t.date :fecha_inicio, null: false
      t.date :fecha_fin, null: false
      t.string :estado, default: "planning", null: false

      t.timestamps
    end

    create_table :daily_snapshots do |t|
      t.references :sprint, null: false, foreign_key: true
      t.date :fecha, null: false
      t.integer :puntos_restantes, null: false
      t.integer :horas_restantes, null: false

      t.timestamps
    end
    add_index :daily_snapshots, %i[sprint_id fecha], unique: true

    add_reference :backlog_items, :sprint, null: true, foreign_key: true
  end
end
