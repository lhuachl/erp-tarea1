class StockMovement < ApplicationRecord
  TIPOS = %w[entrada salida ajuste].freeze

  belongs_to :material

  validates :tipo, inclusion: { in: TIPOS }
  validates :cantidad, numericality: { greater_than: 0 }

  # Aplica el efecto del movimiento sobre el material y persiste ambos de forma
  # atómica. Devuelve true si se registró, false si el movimiento es inválido y
  # :stock_insuficiente si una salida dejaría el stock negativo.
  def registrar
    return false unless valid?
    return :stock_insuficiente if stock_resultante.negative?

    transaction do
      material.update!(stock_actual: stock_resultante)
      save!
    end
    true
  end

  def stock_resultante
    case tipo
    when "entrada" then material.stock_actual + cantidad
    when "salida" then material.stock_actual - cantidad
    else cantidad
    end
  end
end
