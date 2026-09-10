require "rails_helper"

RSpec.describe "Api::V1::Materials", type: :request do
  def payload(overrides = {})
    { nombre: "Harina", unidad: "kg", stock_actual: 10, stock_min: 2, costo_unitario: 3.5 }.merge(overrides)
  end

  describe "POST /api/v1/materials" do
    # @S-REP-01
    it "crea un insumo válido con stock inicial" do
      post "/api/v1/materials", params: payload, as: :json
      expect(response).to have_http_status(:created)
      data = JSON.parse(response.body)["data"]
      expect(data).to include(
        "nombre" => "Harina", "unidad" => "kg", "stock_actual" => 10.0,
        "stock_min" => 2.0, "costo_unitario" => 3.5
      )
    end

    # @S-REP-02
    { "nombre vacío" => { nombre: "" }, "unidad inválida" => { unidad: "caja" },
      "stock_actual negativo" => { stock_actual: -1 }, "stock_min negativo" => { stock_min: -1 },
      "costo_unitario negativo" => { costo_unitario: -0.5 } }.each do |motivo, overrides|
      it "rechaza #{motivo} sin crear insumo" do
        expect do
          post "/api/v1/materials", params: payload(overrides), as: :json
        end.not_to change(Material, :count)
        expect(response).to have_http_status(422)
        expect(JSON.parse(response.body)["errors"].first["code"]).to eq("validation_failed")
      end
    end

    # @S-REP-03
    it "rechaza un nombre duplicado" do
      create(:material, nombre: "Harina")
      expect do
        post "/api/v1/materials", params: payload, as: :json
      end.not_to change(Material, :count)
      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body)["errors"].first["code"]).to eq("nombre_duplicado")
    end

    it "rechaza critico enviado por el cliente" do
      post "/api/v1/materials", params: payload(critico: true), as: :json
      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body)["errors"].first["code"]).to eq("readonly_field")
    end
  end

  describe "GET /api/v1/materials" do
    # @S-REP-07
    it "filtra solo los críticos con solo_criticos=true (incluye el límite)" do
      create(:material, nombre: "Harina", stock_actual: 2, stock_min: 2)
      create(:material, nombre: "Azúcar", stock_actual: 1, stock_min: 3)
      create(:material, nombre: "Manteca", stock_actual: 8, stock_min: 2)

      get "/api/v1/materials?solo_criticos=true"
      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)["data"]
      expect(data.map { _1["nombre"] }).to eq(%w[Harina Azúcar])
      expect(data).to all(include("critico" => true))
    end

    # @S-REP-10
    it "lista todos los insumos sin filtro" do
      create(:material, nombre: "Harina", stock_actual: 10)
      create(:material, nombre: "Azúcar", stock_actual: 5)

      get "/api/v1/materials"
      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)["data"]
      expect(data.map { |m| [ m["nombre"], m["stock_actual"] ] }).to eq([ [ "Harina", 10.0 ], [ "Azúcar", 5.0 ] ])
    end
  end

  describe "GET /api/v1/materials/:id" do
    # @S-REP-10
    it "obtiene un insumo por id" do
      material = create(:material, nombre: "Azúcar", stock_actual: 5)
      get "/api/v1/materials/#{material.id}"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["data"]).to include("nombre" => "Azúcar", "stock_actual" => 5.0)
    end

    it "devuelve 404 si no existe" do
      get "/api/v1/materials/999999"
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)["errors"].first["code"]).to eq("not_found")
    end
  end

  describe "PATCH /api/v1/materials/:id" do
    let(:material) { create(:material, nombre: "Harina", unidad: "kg", stock_actual: 10, stock_min: 2, costo_unitario: 3.5) }

    # @S-REP-08
    it "edita los campos editables y conserva el stock" do
      patch "/api/v1/materials/#{material.id}",
            params: { nombre: "Harina 000", unidad: "g", stock_min: 500, costo_unitario: 4.0 }, as: :json
      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)["data"]
      expect(data).to include("nombre" => "Harina 000", "unidad" => "g", "stock_min" => 500.0, "costo_unitario" => 4.0)
      expect(material.reload.stock_actual).to eq(10)
    end

    # @S-REP-09
    it "rechaza stock_actual con readonly_field y conserva el stock" do
      patch "/api/v1/materials/#{material.id}", params: { stock_actual: 99 }, as: :json
      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body)["errors"].first["code"]).to eq("readonly_field")
      expect(material.reload.stock_actual).to eq(10)
    end

    it "rechaza nombre duplicado" do
      create(:material, nombre: "Azúcar")
      patch "/api/v1/materials/#{material.id}", params: { nombre: "Azúcar" }, as: :json
      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body)["errors"].first["code"]).to eq("nombre_duplicado")
    end

    it "devuelve 404 si no existe" do
      patch "/api/v1/materials/999999", params: { nombre: "X" }, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end
end
