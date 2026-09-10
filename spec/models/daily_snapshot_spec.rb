require "rails_helper"

RSpec.describe DailySnapshot, type: :model do
  let(:sprint) { create(:sprint, estado: "activo") }

  describe "validación de rango de fecha" do
    # @S-AGL-16: los extremos del rango son válidos
    it "acepta fecha en los límites del rango del sprint" do
      expect(build(:daily_snapshot, sprint: sprint, fecha: sprint.fecha_inicio)).to be_valid
      expect(build(:daily_snapshot, sprint: sprint, fecha: sprint.fecha_fin)).to be_valid
    end

    # @S-AGL-17: fecha fuera del rango con mensaje exacto
    it "rechaza fecha anterior al inicio del sprint" do
      snapshot = build(:daily_snapshot, sprint: sprint, fecha: sprint.fecha_inicio - 1)
      expect(snapshot).not_to be_valid
      expect(snapshot.errors[:fecha]).to include("debe estar dentro del rango del sprint")
    end

    # @S-AGL-17: fecha fuera del rango con mensaje exacto
    it "rechaza fecha posterior al fin del sprint" do
      snapshot = build(:daily_snapshot, sprint: sprint, fecha: sprint.fecha_fin + 1)
      expect(snapshot).not_to be_valid
      expect(snapshot.errors[:fecha]).to include("debe estar dentro del rango del sprint")
    end

    # @S-AGL-17: la guarda de fecha nula evita evaluar el rango
    it "rechaza fecha nula" do
      snapshot = build(:daily_snapshot, sprint: sprint, fecha: nil)
      expect(snapshot).not_to be_valid
      expect(snapshot.errors[:fecha]).to include("can't be blank")
    end

    # @S-AGL-17: sin sprint no se evalúa el rango (evita comparar contra nil)
    it "rechaza sprint nulo sin evaluar el rango" do
      snapshot = build(:daily_snapshot, sprint: nil, fecha: Date.current)
      expect(snapshot).not_to be_valid
      expect(snapshot.errors[:sprint]).to be_present
    end
  end

  describe "validación de puntos y horas" do
    # @S-AGL-17: cero es válido (mata el mutante >= 0 -> > 0)
    it "acepta puntos y horas en cero" do
      expect(build(:daily_snapshot, sprint: sprint, puntos_restantes: 0, horas_restantes: 0)).to be_valid
    end

    # @S-AGL-17: negativos rechazados con mensaje
    it "rechaza puntos y horas negativos" do
      snapshot = build(:daily_snapshot, sprint: sprint, puntos_restantes: -1, horas_restantes: -5)
      expect(snapshot).not_to be_valid
      expect(snapshot.errors[:puntos_restantes]).to include("must be greater than or equal to 0")
      expect(snapshot.errors[:horas_restantes]).to include("must be greater than or equal to 0")
    end

    # @S-AGL-17: deben ser enteros
    it "rechaza puntos no enteros" do
      snapshot = build(:daily_snapshot, sprint: sprint, puntos_restantes: 1.5)
      expect(snapshot).not_to be_valid
      expect(snapshot.errors[:puntos_restantes]).to include("must be an integer")
    end
  end

  describe "unicidad por (sprint, fecha)" do
    # @S-AGL-18: un segundo snapshot para la misma fecha es inválido
    it "rechaza un segundo snapshot para la misma fecha" do
      create(:daily_snapshot, sprint: sprint, fecha: sprint.fecha_inicio)
      segundo = build(:daily_snapshot, sprint: sprint, fecha: sprint.fecha_inicio)
      expect(segundo).not_to be_valid
      expect(segundo.errors[:fecha]).to include("has already been taken")
    end

    # @S-AGL-18: la unicidad está acotada al sprint
    it "permite la misma fecha en otro sprint" do
      otro = create(:sprint, estado: "activo", fecha_inicio: Date.current - 2, fecha_fin: Date.current + 5)
      create(:daily_snapshot, sprint: sprint, fecha: Date.current)
      expect(build(:daily_snapshot, sprint: otro, fecha: Date.current)).to be_valid
    end
  end
end
