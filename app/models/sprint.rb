class Sprint < ApplicationRecord
  ESTADOS = %w[planning activo cerrado].freeze
  TRANSICIONES = { "planning" => "activo", "activo" => "cerrado" }.freeze

  enum :estado, ESTADOS.index_by(&:itself), default: :planning

  has_many :backlog_items, dependent: :nullify
  has_many :daily_snapshots, dependent: :destroy

  validates :nombre, presence: true
  validate :fecha_fin_no_anterior_a_inicio
  # Las fechas de un sprint se fijan al planificarlo; los sprints históricos
  # (activo/cerrado) pueden tener fechas pasadas.
  validate :fecha_fin_no_pasada, on: :create, if: -> { planning? }

  def transicion_valida?(destino)
    destino == estado || TRANSICIONES[estado] == destino
  end

  def historias_en_sprint
    backlog_items.where(estado: "en_sprint")
  end

  private

  def fecha_fin_no_anterior_a_inicio
    return if fecha_inicio.blank? || fecha_fin.blank?

    errors.add(:fecha_fin, "debe ser posterior o igual a fecha_inicio") if fecha_fin < fecha_inicio
  end

  def fecha_fin_no_pasada
    return if fecha_fin.blank?

    errors.add(:fecha_fin, "debe ser hoy o posterior") if fecha_fin < Date.current
  end
end
