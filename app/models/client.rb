class Client < ApplicationRecord
  # Unicidad (nombre, telefono) tal como vengan. Sin teléfono no aplica: nil no choca
  # (NULL es distinto en Postgres) y el teléfono vacío se normaliza a nil.
  normalizes :telefono, with: ->(telefono) { telefono.presence }

  validates :nombre, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :telefono, uniqueness: { scope: :nombre }, if: -> { telefono.present? }

  # Guard futuro con Ventas: mientras Client no defina #pedidos (asociación no modelada),
  # está dormido y no bloquea el borrado.
  def tiene_pedidos?
    respond_to?(:pedidos) && pedidos.exists?
  end
end
