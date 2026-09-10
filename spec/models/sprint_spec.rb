require "rails_helper"

RSpec.describe Sprint, type: :model do
  describe "validación de nombre" do
    # @S-AGL-11: nombre obligatorio y no vacío
    it "rechaza nombre vacío" do
      sprint = build(:sprint, nombre: "")
      expect(sprint).not_to be_valid
      expect(sprint.errors[:nombre]).to include("can't be blank")
    end
  end

  describe "validaciones de fecha en creación" do
    # @S-AGL-11: fecha_fin >= fecha_inicio (fechas futuras, aislado de fecha_fin >= hoy)
    it "rechaza fecha_fin anterior a fecha_inicio" do
      sprint = build(:sprint, fecha_inicio: Date.current + 10, fecha_fin: Date.current + 5)
      expect(sprint).not_to be_valid
      expect(sprint.errors[:fecha_fin]).to include("debe ser posterior o igual a fecha_inicio")
    end

    # @S-AGL-11: fecha_fin >= hoy
    it "rechaza fecha_fin anterior a hoy" do
      sprint = build(:sprint, fecha_inicio: Date.current - 10, fecha_fin: Date.current - 3)
      expect(sprint).not_to be_valid
      expect(sprint.errors[:fecha_fin]).to include("debe ser hoy o posterior")
    end

    # @S-AGL-10: el límite inferior es inclusivo (mata el mutante < -> <=)
    it "acepta fecha_fin igual a hoy" do
      sprint = build(:sprint, fecha_inicio: Date.current - 5, fecha_fin: Date.current)
      expect(sprint).to be_valid
    end

    # @S-AGL-10: fecha_fin igual a fecha_inicio es válida (mata el mutante < -> <=)
    it "acepta fecha_fin igual a fecha_inicio" do
      sprint = build(:sprint, fecha_inicio: Date.current + 3, fecha_fin: Date.current + 3)
      expect(sprint).to be_valid
    end

    # @S-AGL-10: no se exige fecha_inicio >= hoy, solo que el fin no haya pasado
    it "acepta fecha_inicio pasada cuando fecha_fin es futura" do
      sprint = build(:sprint, fecha_inicio: Date.current - 10, fecha_fin: Date.current + 1)
      expect(sprint).to be_valid
    end

    # @S-AGL-19: los sprints históricos (no planning) pueden terminar en el pasado
    it "no valida fecha_fin pasada fuera de planning" do
      sprint = build(:sprint, estado: "cerrado", fecha_inicio: Date.current - 14, fecha_fin: Date.current - 3)
      expect(sprint).to be_valid
    end

    # @S-AGL-11: fechas obligatorias
    it "rechaza ambas fechas nulas" do
      sprint = build(:sprint, fecha_inicio: nil, fecha_fin: nil)
      expect(sprint).not_to be_valid
      expect(sprint.errors[:fecha_inicio]).to include("can't be blank")
      expect(sprint.errors[:fecha_fin]).to include("can't be blank")
    end

    # @S-AGL-11: fecha_inicio nula con fecha_fin presente no revienta las comparaciones
    it "rechaza fecha_inicio nula con fecha_fin presente" do
      sprint = build(:sprint, fecha_inicio: nil, fecha_fin: Date.current + 5)
      expect(sprint).not_to be_valid
      expect(sprint.errors[:fecha_inicio]).to include("can't be blank")
    end

    # @S-AGL-11: fecha_fin nula con fecha_inicio presente no revienta las comparaciones
    it "rechaza fecha_fin nula con fecha_inicio presente" do
      sprint = build(:sprint, fecha_inicio: Date.current, fecha_fin: nil)
      expect(sprint).not_to be_valid
      expect(sprint.errors[:fecha_fin]).to include("can't be blank")
    end
  end

  describe "#transicion_valida?" do
    # @S-AGL-12: planning -> activo -> cerrado en orden
    it "permite planning -> activo -> cerrado" do
      sprint = build(:sprint, estado: "planning")
      expect(sprint.transicion_valida?("activo")).to be(true)
      sprint.estado = "activo"
      expect(sprint.transicion_valida?("cerrado")).to be(true)
    end

    # @S-AGL-13: la rama idempotente destino == estado es válida
    it "acepta la transición al mismo estado" do
      expect(build(:sprint, estado: "planning").transicion_valida?("planning")).to be(true)
      expect(build(:sprint, estado: "activo").transicion_valida?("activo")).to be(true)
      expect(build(:sprint, estado: "cerrado").transicion_valida?("cerrado")).to be(true)
    end

    # @S-AGL-13: sin saltos ni retrocesos
    it "rechaza saltos y retrocesos" do
      expect(build(:sprint, estado: "planning").transicion_valida?("cerrado")).to be(false)
      expect(build(:sprint, estado: "activo").transicion_valida?("planning")).to be(false)
      expect(build(:sprint, estado: "cerrado").transicion_valida?("activo")).to be(false)
    end
  end

  describe "#historias_en_sprint" do
    # @S-AGL-15: solo cuenta items asignados y en estado en_sprint
    it "cuenta solo backlog_items del sprint en estado en_sprint" do
      sprint = create(:sprint)
      create(:backlog_item, sprint: sprint, estado: "en_sprint")
      create(:backlog_item, sprint: sprint, estado: "backlog")
      create(:backlog_item, sprint: create(:sprint), estado: "en_sprint")

      expect(sprint.historias_en_sprint.count).to eq(1)
    end
  end
end
