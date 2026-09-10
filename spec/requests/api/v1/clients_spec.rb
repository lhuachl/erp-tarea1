require "rails_helper"

RSpec.describe "Api::V1::Clients", type: :request do
  describe "POST /api/v1/clients" do
    # @S-REP-20
    it "crea un cliente con todos sus datos" do
      post "/api/v1/clients", params: {
        nombre: "María López", telefono: "555-1234", email: "maria@example.com",
        direccion: "Calle Falsa 123", notas: "Prefiere tortas de chocolate"
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["data"]).to include(
        "nombre" => "María López", "telefono" => "555-1234", "email" => "maria@example.com",
        "direccion" => "Calle Falsa 123", "notas" => "Prefiere tortas de chocolate"
      )
    end

    # @S-REP-21
    it "crea un cliente solo con su nombre, sin email ni telefono" do
      post "/api/v1/clients", params: { nombre: "Cliente ocasional" }, as: :json

      expect(response).to have_http_status(:created)
      data = JSON.parse(response.body)["data"]
      expect(data["nombre"]).to eq("Cliente ocasional")
      expect(data["email"]).to be_nil
      expect(data["telefono"]).to be_nil
    end

    # @S-REP-22
    { "nombre vacío" => { nombre: "" }, "email sin arroba" => { email: "sin-arroba" },
      "email incompleto" => { email: "maria@" } }.each do |motivo, overrides|
      it "rechaza #{motivo} sin crear cliente" do
        expect do
          post "/api/v1/clients", params: { nombre: "María López" }.merge(overrides), as: :json
        end.not_to change(Client, :count)

        expect(response).to have_http_status(422)
        expect(JSON.parse(response.body)["errors"].first["code"]).to eq("validation_failed")
      end
    end

    # @S-REP-23
    it "rechaza un cliente duplicado por nombre y telefono" do
      create(:client, nombre: "María López", telefono: "555-1234")
      expect do
        post "/api/v1/clients",
             params: { nombre: "María López", telefono: "555-1234", email: "otra@example.com" }, as: :json
      end.not_to change(Client, :count)

      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body)["errors"].first["code"]).to eq("cliente_duplicado")
    end
  end

  describe "PATCH /api/v1/clients/:id" do
    # @S-REP-24
    it "edita los campos enviados y conserva el resto" do
      cliente = create(:client, nombre: "María López", telefono: "555-1234", email: "maria@example.com")

      patch "/api/v1/clients/#{cliente.id}", params: { telefono: "555-9999", direccion: "Calle Nueva 456" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["data"]).to include(
        "nombre" => "María López", "telefono" => "555-9999", "direccion" => "Calle Nueva 456"
      )
    end

    # @S-REP-22
    it "rechaza un email inválido y deja el cliente intacto" do
      cliente = create(:client, email: "maria@example.com")
      patch "/api/v1/clients/#{cliente.id}", params: { email: "sin-arroba" }, as: :json

      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body)["errors"].first["code"]).to eq("validation_failed")
      expect(cliente.reload.email).to eq("maria@example.com")
    end

    it "devuelve 404 si no existe" do
      patch "/api/v1/clients/999999", params: { nombre: "X" }, as: :json
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)["errors"].first["code"]).to eq("not_found")
    end
  end

  describe "DELETE /api/v1/clients/:id" do
    # @S-REP-25
    it "elimina un cliente sin pedidos asociados" do
      cliente = create(:client)
      delete "/api/v1/clients/#{cliente.id}"

      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_blank
      expect(Client.exists?(cliente.id)).to be(false)
    end

    # @S-REP-26
    it "rechaza eliminar un cliente con pedidos y lo deja intacto" do
      cliente = create(:client)
      allow_any_instance_of(Client).to receive(:tiene_pedidos?).and_return(true)

      expect do
        delete "/api/v1/clients/#{cliente.id}"
      end.not_to change(Client, :count)

      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body)["errors"].first["code"]).to eq("cliente_con_pedidos")
    end

    it "devuelve 404 si no existe" do
      delete "/api/v1/clients/999999"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/clients" do
    # @S-REP-27
    it "filtra por nombre parcial sin distinguir mayúsculas ni acentos" do
      create(:client, nombre: "María López", telefono: "555-1234")
      create(:client, nombre: "Pedro López", telefono: "555-5678")
      create(:client, nombre: "Ana Pérez", telefono: "555-9012")

      get "/api/v1/clients?q=lop"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["data"].map { _1["nombre"] }).to eq([ "María López", "Pedro López" ])
    end

    # @S-REP-28
    it "lista todos los clientes sin filtro" do
      create(:client, nombre: "María López")
      create(:client, nombre: "Ana Pérez")

      get "/api/v1/clients"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["data"].size).to eq(2)
    end
  end

  describe "GET /api/v1/clients/:id" do
    # @S-REP-28
    it "obtiene un cliente por id" do
      cliente = create(:client, nombre: "María López")
      get "/api/v1/clients/#{cliente.id}"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["data"]["nombre"]).to eq("María López")
    end

    it "devuelve 404 si no existe" do
      get "/api/v1/clients/999999"
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)["errors"].first["code"]).to eq("not_found")
    end
  end
end
