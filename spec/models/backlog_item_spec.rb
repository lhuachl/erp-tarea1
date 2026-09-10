require "rails_helper"

RSpec.describe BacklogItem, type: :model do
  describe "#wsjf" do
    # @S-AGL-01: wsjf = (cod_value + cod_time_criticality + cod_risk_reduction) / cod_duration
    it "calcula wsjf a partir de los campos CoD" do
      item = build(:backlog_item, cod_value: 8, cod_time_criticality: 5, cod_risk_reduction: 3, cod_duration: 2)
      expect(item.wsjf).to eq(8.0)
    end

    # Contrato invariante 1: cod_duration 0 evita division por cero y devuelve 0
    it "devuelve 0 si cod_duration es 0" do
      item = build(:backlog_item, cod_value: 8, cod_time_criticality: 5, cod_risk_reduction: 3, cod_duration: 0)
      expect(item.wsjf).to eq(0)
    end
  end

  describe "#cod_profile" do
    # Regla CoD documentada: expedite si wsjf >= 20; fixed_date si criticidad temporal >= 8;
    # standard si wsjf >= 5; intangible en el resto.
    it "devuelve expedite con wsjf muy alto" do
      item = build(:backlog_item, cod_value: 12, cod_time_criticality: 8, cod_risk_reduction: 10, cod_duration: 1)
      expect(item.wsjf).to eq(30.0)
      expect(item.cod_profile).to eq("expedite")
    end

    it "devuelve fixed_date con criticidad temporal alta" do
      item = build(:backlog_item, cod_value: 2, cod_time_criticality: 8, cod_risk_reduction: 1, cod_duration: 4)
      expect(item.cod_profile).to eq("fixed_date")
    end

    it "devuelve standard con wsjf medio" do
      item = build(:backlog_item, cod_value: 6, cod_time_criticality: 3, cod_risk_reduction: 3, cod_duration: 2)
      expect(item.wsjf).to eq(6.0)
      expect(item.cod_profile).to eq("standard")
    end

    it "devuelve intangible con wsjf bajo" do
      item = build(:backlog_item, cod_value: 1, cod_time_criticality: 1, cod_risk_reduction: 1, cod_duration: 10)
      expect(item.cod_profile).to eq("intangible")
    end
  end

  describe "transiciones de estado" do
    it "permite backlog -> listo -> en_sprint -> done" do
      item = build(:backlog_item, estado: "backlog")
      expect(item.transicion_valida?("listo")).to be(true)
      item.estado = "listo"
      expect(item.transicion_valida?("en_sprint")).to be(true)
      item.estado = "en_sprint"
      expect(item.transicion_valida?("done")).to be(true)
    end

    # @S-AGL-04: saltos y retrocesos rechazados
    it "rechaza salto de backlog a en_sprint" do
      item = build(:backlog_item, estado: "backlog")
      expect(item.transicion_valida?("en_sprint")).to be(false)
      expect(item.transicion_valida?("done")).to be(false)
    end

    it "rechaza retroceso de listo a backlog" do
      item = build(:backlog_item, estado: "listo")
      expect(item.transicion_valida?("backlog")).to be(false)
    end

    it "rechaza retroceso de en_sprint a listo y de done a en_sprint" do
      item = build(:backlog_item, estado: "en_sprint")
      expect(item.transicion_valida?("listo")).to be(false)
      item.estado = "done"
      expect(item.transicion_valida?("en_sprint")).to be(false)
    end

    it "rechaza destino inexistente" do
      item = build(:backlog_item, estado: "backlog")
      expect(item.transicion_valida?("urgente")).to be(false)
    end
  end

  describe ".sorted" do
    # @S-AGL-06: prioridad (alta > media > baja) y luego wsjf desc
    it "ordena por prioridad y wsjf descendente" do
      create(:backlog_item, titulo: "Torta de cumpleaños", prioridad: "alta", cod_value: 8, cod_time_criticality: 5, cod_risk_reduction: 3, cod_duration: 2)
      create(:backlog_item, titulo: "Cobrar pedidos pendientes", prioridad: "alta", cod_value: 4, cod_time_criticality: 3, cod_risk_reduction: 2, cod_duration: 3)
      create(:backlog_item, titulo: "Reparto del turno tarde", prioridad: "media", cod_value: 6, cod_time_criticality: 3, cod_risk_reduction: 3, cod_duration: 2)
      create(:backlog_item, titulo: "Inventario de harina", prioridad: "baja", cod_value: 8, cod_time_criticality: 5, cod_risk_reduction: 5, cod_duration: 2)

      expect(BacklogItem.sorted.map(&:titulo)).to eq(
        [ "Torta de cumpleaños", "Cobrar pedidos pendientes", "Reparto del turno tarde", "Inventario de harina" ]
      )
    end
  end
end
