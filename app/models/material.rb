class Material < ApplicationRecord
  UNIDADES = %w[kg g l ml unidad].freeze

  has_many :stock_movements

  validates :nombre, presence: true, uniqueness: true
  validates :unidad, inclusion: { in: UNIDADES }
  validates :stock_actual, :stock_min, :costo_unitario, numericality: { greater_than_or_equal_to: 0 }

  def critico?
    stock_actual <= stock_min
  end
end
