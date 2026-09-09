class BacklogItem < ApplicationRecord
  PRIORIDADES = %w[alta media baja].freeze
  ESTADOS = %w[backlog listo en_sprint done].freeze
  TRANSICIONES = { "backlog" => "listo", "listo" => "en_sprint", "en_sprint" => "done" }.freeze

  # Regla CoD (documentada en specs/agile/backlog.feature): expedite si wsjf muy alto,
  # fixed_date si criticidad temporal alta, standard si wsjf medio, intangible si bajo.
  WSJF_EXPEDITE = 20
  WSJF_STANDARD = 5
  TIME_CRITICALITY_ALTA = 8

  enum :prioridad, PRIORIDADES.index_by(&:itself), default: :media
  enum :estado, ESTADOS.index_by(&:itself), default: :backlog

  validates :titulo, presence: true
  validates :story_points, numericality: { only_integer: true, greater_than: 0, message: "debe ser un entero mayor a 0" }

  def wsjf
    return 0 if cod_duration.zero?

    (cod_value + cod_time_criticality + cod_risk_reduction).fdiv(cod_duration)
  end

  def cod_profile
    return "expedite" if wsjf >= WSJF_EXPEDITE
    return "fixed_date" if cod_time_criticality >= TIME_CRITICALITY_ALTA
    return "standard" if wsjf >= WSJF_STANDARD

    "intangible"
  end

  def transicion_valida?(destino)
    destino == estado || TRANSICIONES[estado] == destino
  end

  def self.sorted
    rango_prioridad = { "alta" => 0, "media" => 1, "baja" => 2 }
    all.sort_by { |item| [rango_prioridad.fetch(item.prioridad, 3), -item.wsjf] }
  end
end