require "rails_helper"

RSpec.describe Material, type: :model do
  describe "validaciones" do
    it "exige nombre presente" do
      expect(build(:material, nombre: "")).not_to be_valid
    end

    it "exige nombre único" do
      create(:material, nombre: "Harina")
      expect(build(:material, nombre: "Harina")).not_to be_valid
    end

    it "acepta todas las unidades del contrato" do
      Material::UNIDADES.each do |unidad|
        expect(build(:material, unidad: unidad)).to be_valid
      end
    end

    it "rechaza una unidad fuera del enum" do
      material = build(:material, unidad: "caja")
      expect(material).not_to be_valid
      expect(material.errors[:unidad]).to be_present
    end

    %i[stock_actual stock_min costo_unitario].each do |campo|
      it "acepta #{campo} en cero" do
        expect(build(:material, campo => 0)).to be_valid
      end

      it "acepta #{campo} decimal positivo" do
        expect(build(:material, campo => 2.5)).to be_valid
      end

      it "rechaza #{campo} negativo" do
        expect(build(:material, campo => -0.5)).not_to be_valid
      end
    end
  end

  describe "#critico?" do
    it "es crítico cuando el stock iguala el mínimo" do
      expect(build(:material, stock_actual: 2, stock_min: 2).critico?).to be(true)
    end

    it "es crítico cuando el stock está por debajo del mínimo" do
      expect(build(:material, stock_actual: 1, stock_min: 3).critico?).to be(true)
    end

    it "no es crítico cuando el stock supera el mínimo" do
      expect(build(:material, stock_actual: 8, stock_min: 2).critico?).to be(false)
    end
  end

  describe "asociación" do
    it "tiene muchos movimientos de stock" do
      material = create(:material)
      create(:stock_movement, material: material, tipo: "entrada", cantidad: 1)
      expect(material.stock_movements.count).to eq(1)
    end
  end
end
