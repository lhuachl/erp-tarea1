require "rails_helper"

RSpec.describe Sprint, type: :model do
  describe "validaciones" do
    # Contrato invariante 1: nombre obligatorio y no vacío
    it "exige nombre" do
      expect(build(:sprint, nombre: "")).not_to be_valid
    end

    # Contrato invariante 2: fecha_fin >= fecha_inicio
    it "rechaza fecha_fin anterior a fecha_inicio" do
      sprint = build(:sprint, fecha_inicio: Date.current, fecha_fin: Date.current - 1)
      expect(sprint).not_to be_valid
      expect(sprint.errors[:fecha_fin]).to be_present
    end

    # Contrato invariante 2: creación planning no puede terminar antes de hoy
    it "rechaza un sprint planning que termina antes de hoy" do
      sprint = build(:sprint, fecha_inicio: Date.current - 10, fecha_fin: Date.current - 1)
      expect(sprint).not_to be_valid
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

    # @S-AGL-13: sin saltos ni retrocesos
    it "rechaza saltos y retrocesos" do
      expect(build(:sprint, estado: "planning").transicion_valida?("cerrado")).to be(false)
      expect(build(:sprint, estado: "activo").transicion_valida?("planning")).to be(false)
      expect(build(:sprint, estado: "cerrado").transicion_valida?("activo")).to be(false)
    end
  end

  describe "#historias_en_sprint" do
    # Contrato invariante 6: solo cuenta items asignados y en estado en_sprint
    it "cuenta solo backlog_items del sprint en estado en_sprint" do
      sprint = create(:sprint)
      create(:backlog_item, sprint: sprint, estado: "en_sprint")
      create(:backlog_item, sprint: sprint, estado: "backlog")
      create(:backlog_item, sprint: create(:sprint), estado: "en_sprint")

      expect(sprint.historias_en_sprint.count).to eq(1)
    end
  end
end
