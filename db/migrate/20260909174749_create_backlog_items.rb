class CreateBacklogItems < ActiveRecord::Migration[8.1]
  def change
    create_table :backlog_items do |t|
      t.string :titulo, null: false
      t.string :descripcion, default: "", null: false
      t.integer :story_points, null: false
      t.string :prioridad, default: "media", null: false
      t.string :estado, default: "backlog", null: false
      t.integer :cod_value, default: 0, null: false
      t.integer :cod_time_criticality, default: 0, null: false
      t.integer :cod_risk_reduction, default: 0, null: false
      t.integer :cod_duration, default: 0, null: false

      t.timestamps
    end
  end
end