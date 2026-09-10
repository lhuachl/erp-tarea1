require "rails_helper"

RSpec.describe DailySnapshot, type: :model do
  let(:sprint) { create(:sprint, estado: "activo") }

  it "es válido dentro del rango del sprint" do
    expect(build(:daily_snapshot, sprint: sprint, fecha: sprint.fecha_inicio)).to be_valid
  end

  # Contrato invariante 8: fecha dentro del rango del sprint
  it "rechaza fecha fuera del rango del sprint" do
    expect(build(:daily_snapshot, sprint: sprint, fecha: sprint.fecha_fin + 1)).not_to be_valid
  end

  # Contrato invariante 8: enteros >= 0
  it "rechaza puntos u horas negativos" do
    expect(build(:daily_snapshot, sprint: sprint, puntos_restantes: -1)).not_to be_valid
    expect(build(:daily_snapshot, sprint: sprint, horas_restantes: -5)).not_to be_valid
  end

  # Contrato invariante 9: unicidad (sprint, fecha)
  it "rechaza un segundo snapshot para la misma fecha" do
    create(:daily_snapshot, sprint: sprint, fecha: sprint.fecha_inicio)
    expect(build(:daily_snapshot, sprint: sprint, fecha: sprint.fecha_inicio)).not_to be_valid
  end
end
