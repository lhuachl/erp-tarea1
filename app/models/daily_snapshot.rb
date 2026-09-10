class DailySnapshot < ApplicationRecord
  belongs_to :sprint

  validates :fecha, presence: true
  validates :puntos_restantes, :horas_restantes,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :fecha, uniqueness: { scope: :sprint_id }
  validate :fecha_dentro_del_sprint

  private

  def fecha_dentro_del_sprint
    return if fecha.blank? || sprint.blank?
    return if fecha.between?(sprint.fecha_inicio, sprint.fecha_fin)

    errors.add(:fecha, "debe estar dentro del rango del sprint")
  end
end
