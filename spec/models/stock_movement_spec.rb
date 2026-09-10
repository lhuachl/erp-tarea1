require "rails_helper"

RSpec.describe StockMovement, type: :model do
  describe "validaciones" do
    it "acepta los tipos del contrato" do
      StockMovement::TIPOS.each do |tipo|
        expect(build(:stock_movement, tipo: tipo)).to be_valid
      end
    end

    it "rechaza un tipo fuera del enum" do
      expect(build(:stock_movement, tipo: "transferencia")).not_to be_valid
    end

    it "rechaza cantidad cero o negativa" do
      expect(build(:stock_movement, cantidad: 0)).not_to be_valid
      expect(build(:stock_movement, cantidad: -3)).not_to be_valid
    end

    it "acepta cantidad positiva" do
      expect(build(:stock_movement, cantidad: 2.5)).to be_valid
    end
  end

  describe "#stock_resultante" do
    let(:material) { build(:material, stock_actual: 10) }

    it "suma en una entrada" do
      expect(build(:stock_movement, material: material, tipo: "entrada", cantidad: 5).stock_resultante).to eq(15)
    end

    it "resta en una salida" do
      expect(build(:stock_movement, material: material, tipo: "salida", cantidad: 4).stock_resultante).to eq(6)
    end

    it "fija el stock en un ajuste" do
      expect(build(:stock_movement, material: material, tipo: "ajuste", cantidad: 7).stock_resultante).to eq(7)
    end
  end

  describe "#registrar" do
    it "registra una entrada y suma el stock" do
      material = create(:material, stock_actual: 10)
      movimiento = material.stock_movements.new(tipo: "entrada", cantidad: 5, referencia: "compra")
      resultado = nil
      expect { resultado = movimiento.registrar }.to change(StockMovement, :count).by(1)
      expect(resultado).to be(true)
      expect(material.reload.stock_actual).to eq(15)
    end

    it "registra una salida y resta el stock" do
      material = create(:material, stock_actual: 10)
      movimiento = material.stock_movements.new(tipo: "salida", cantidad: 4)
      expect(movimiento.registrar).to be(true)
      expect(material.reload.stock_actual).to eq(6)
    end

    it "registra un ajuste y fija el stock nuevo" do
      material = create(:material, stock_actual: 10)
      movimiento = material.stock_movements.new(tipo: "ajuste", cantidad: 7)
      expect(movimiento.registrar).to be(true)
      expect(material.reload.stock_actual).to eq(7)
    end

    it "permite una salida que deja el stock exactamente en cero" do
      material = create(:material, stock_actual: 10)
      movimiento = material.stock_movements.new(tipo: "salida", cantidad: 10)
      expect(movimiento.registrar).to be(true)
      expect(material.reload.stock_actual).to eq(0)
    end

    it "rechaza una salida que dejaría stock negativo sin persistir nada" do
      material = create(:material, stock_actual: 10)
      movimiento = material.stock_movements.new(tipo: "salida", cantidad: 12)
      resultado = nil
      expect { resultado = movimiento.registrar }.not_to change(StockMovement, :count)
      expect(resultado).to eq(:stock_insuficiente)
      expect(material.reload.stock_actual).to eq(10)
    end

    it "rechaza un movimiento inválido sin tocar el stock" do
      material = create(:material, stock_actual: 10)
      movimiento = material.stock_movements.new(tipo: "transferencia", cantidad: 5)
      resultado = nil
      expect { resultado = movimiento.registrar }.not_to change(StockMovement, :count)
      expect(resultado).to be(false)
      expect(material.reload.stock_actual).to eq(10)
    end

    it "no persiste el movimiento si falla la actualización del stock" do
      material = create(:material, stock_actual: 10)
      movimiento = material.stock_movements.new(tipo: "entrada", cantidad: 5)
      allow(material).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(material))
      expect { movimiento.registrar }.to raise_error(ActiveRecord::RecordInvalid)
      expect(StockMovement.count).to eq(0)
    end
  end
end
