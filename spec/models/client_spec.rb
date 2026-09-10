require "rails_helper"

RSpec.describe Client, type: :model do
  describe "validaciones" do
    # @S-REP-22
    it "exige nombre presente y no vacío" do
      expect(build(:client, nombre: "")).not_to be_valid
      expect(build(:client, nombre: nil)).not_to be_valid
      expect(build(:client, nombre: "María López")).to be_valid
    end

    # @S-REP-21
    it "acepta un cliente solo con nombre" do
      cliente = build(:client, nombre: "Cliente ocasional", telefono: nil, email: nil)
      expect(cliente).to be_valid
    end

    # @S-REP-22
    %w[sin-arroba maria@ @example.com].each do |email|
      it "rechaza el email inválido #{email.inspect}" do
        cliente = build(:client, email: email)
        expect(cliente).not_to be_valid
        expect(cliente.errors[:email]).to be_present
      end
    end

    it "acepta email válido y lo deja opcional" do
      expect(build(:client, email: "maria@example.com")).to be_valid
      expect(build(:client, email: nil)).to be_valid
      expect(build(:client, email: "")).to be_valid
    end

    # @S-REP-23
    it "rechaza duplicar la combinación (nombre, telefono)" do
      create(:client, nombre: "María López", telefono: "555-1234")
      expect(build(:client, nombre: "María López", telefono: "555-1234")).not_to be_valid
    end

    it "permite mismo nombre con distinto telefono" do
      create(:client, nombre: "María López", telefono: "555-1234")
      expect(build(:client, nombre: "María López", telefono: "555-9999")).to be_valid
    end

    it "permite el mismo telefono con distinto nombre" do
      create(:client, nombre: "María López", telefono: "555-1234")
      expect(build(:client, nombre: "Ana Pérez", telefono: "555-1234")).to be_valid
    end

    it "no aplica la unicidad sin telefono" do
      create(:client, nombre: "Cliente ocasional", telefono: nil)
      expect(build(:client, nombre: "Cliente ocasional", telefono: nil)).to be_valid
    end

    it "normaliza el telefono vacío a nil" do
      cliente = build(:client, telefono: "")
      expect(cliente.telefono).to be_nil
      expect(build(:client, nombre: cliente.nombre, telefono: "")).to be_valid
    end
  end

  describe "#tiene_pedidos?" do
    # @S-REP-25 / @S-REP-26 — guard dormido mientras no exista la asociación
    it "es falso cuando no hay asociación de pedidos" do
      expect(build(:client).tiene_pedidos?).to be(false)
    end

    it "es verdadero cuando la asociación reporta pedidos" do
      cliente = build(:client)
      relacion = Struct.new(:exists?).new(true)
      cliente.define_singleton_method(:pedidos) { relacion }
      expect(cliente.tiene_pedidos?).to be(true)
    end

    it "es falso cuando la asociación existe pero no tiene pedidos" do
      cliente = build(:client)
      relacion = Struct.new(:exists?).new(false)
      cliente.define_singleton_method(:pedidos) { relacion }
      expect(cliente.tiene_pedidos?).to be(false)
    end
  end
end
