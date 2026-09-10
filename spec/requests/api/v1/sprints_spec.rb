require "rails_helper"

RSpec.describe "Api::V1::Sprints", type: :request do
  def payload(overrides = {})
    { nombre: "Sprint 1", fecha_inicio: Date.current, fecha_fin: Date.current + 10 }.merge(overrides)
  end

  describe "POST /api/v1/sprints" do
    # @S-AGL-10
    it "crea un sprint en estado planning" do
      post "/api/v1/sprints", params: payload, as: :json
      expect(response).to have_http_status(:created)
      data = JSON.parse(response.body)["data"]
      expect(data["nombre"]).to eq("Sprint 1")
      expect(data["estado"]).to eq("planning")
    end

    # Contrato invariante 3: POST no acepta estado
    it "rechaza estado con 422 readonly_field" do
      post "/api/v1/sprints", params: payload(estado: "activo"), as: :json
      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body)["errors"].first["code"]).to eq("readonly_field")
    end

    # @S-AGL-11
    it "rechaza nombre vacío sin crear registro" do
      expect do
        post "/api/v1/sprints", params: payload(nombre: ""), as: :json
      end.not_to change(Sprint, :count)
      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body)["errors"].first["code"]).to eq("validation_failed")
    end

    # @S-AGL-11
    it "rechaza fecha_fin anterior a fecha_inicio" do
      post "/api/v1/sprints", params: payload(fecha_fin: Date.current - 1), as: :json
      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body)["errors"].first["code"]).to eq("validation_failed")
    end

    # @S-AGL-11
    it "rechaza fechas pasadas" do
      post "/api/v1/sprints",
           params: { nombre: "Sprint 1", fecha_inicio: Date.current - 20, fecha_fin: Date.current - 10 }, as: :json
      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body)["errors"].first["code"]).to eq("validation_failed")
    end
  end

  describe "PATCH /api/v1/sprints/:id" do
    # @S-AGL-12
    it "activa y cierra en orden estricto" do
      sprint = create(:sprint, estado: "planning")
      create(:backlog_item, sprint: sprint, estado: "en_sprint")

      patch "/api/v1/sprints/#{sprint.id}", params: { estado: "activo" }, as: :json
      expect(response).to have_http_status(:ok)
      expect(sprint.reload.estado).to eq("activo")

      patch "/api/v1/sprints/#{sprint.id}", params: { estado: "cerrado" }, as: :json
      expect(response).to have_http_status(:ok)
      expect(sprint.reload.estado).to eq("cerrado")
    end

    # rama idempotente de activar?: reafirmar "activo" no debe revalidar sprint_vacio
    it "permite reafirmar el estado activo sin historias" do
      sprint = create(:sprint, estado: "activo")
      patch "/api/v1/sprints/#{sprint.id}", params: { estado: "activo" }, as: :json
      expect(response).to have_http_status(:ok)
      expect(sprint.reload.estado).to eq("activo")
    end

    # @S-AGL-13
    { "planning" => "cerrado", "activo" => "planning", "cerrado" => "activo" }.each do |actual, solicitado|
      it "rechaza #{actual} -> #{solicitado} con invalid_transition" do
        sprint = create(:sprint, estado: actual)
        patch "/api/v1/sprints/#{sprint.id}", params: { estado: solicitado }, as: :json
        expect(response).to have_http_status(422)
        expect(JSON.parse(response.body)["errors"].first["code"]).to eq("invalid_transition")
        expect(sprint.reload.estado).to eq(actual)
      end
    end

    # @S-AGL-14
    it "rechaza activar un segundo sprint" do
      create(:sprint, estado: "activo")
      otro = create(:sprint, estado: "planning")
      create(:backlog_item, sprint: otro, estado: "en_sprint")

      patch "/api/v1/sprints/#{otro.id}", params: { estado: "activo" }, as: :json
      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body)["errors"].first["code"]).to eq("sprint_activo_duplicado")
      expect(otro.reload.estado).to eq("planning")
    end

    # @S-AGL-15
    it "rechaza activar un sprint sin historias" do
      sprint = create(:sprint, estado: "planning")
      patch "/api/v1/sprints/#{sprint.id}", params: { estado: "activo" }, as: :json
      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body)["errors"].first["code"]).to eq("sprint_vacio")
      expect(sprint.reload.estado).to eq("planning")
    end

    it "no permite editar fechas fuera de planning" do
      sprint = create(:sprint, estado: "activo")
      patch "/api/v1/sprints/#{sprint.id}", params: { fecha_fin: Date.current + 3 }, as: :json
      expect(response).to have_http_status(422)
      expect(sprint.reload.fecha_fin).to eq((Date.current + 10))
    end

    it "devuelve 404 not_found si no existe" do
      patch "/api/v1/sprints/999999", params: { estado: "activo" }, as: :json
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)["errors"].first["code"]).to eq("not_found")
    end
  end

  describe "GET /api/v1/sprints" do
    # @S-AGL-19
    it "lista los sprints con su estado" do
      create(:sprint, nombre: "Sprint 1", estado: "cerrado")
      create(:sprint, nombre: "Sprint 2", estado: "activo")

      get "/api/v1/sprints"
      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)["data"]
      expect(data.map { |s| [ s["nombre"], s["estado"] ] }).to eq([ [ "Sprint 1", "cerrado" ], [ "Sprint 2", "activo" ] ])
    end
  end

  describe "GET /api/v1/sprints/:id" do
    # @S-AGL-19
    it "obtiene un sprint por id" do
      sprint = create(:sprint, nombre: "Sprint 2", estado: "activo")
      get "/api/v1/sprints/#{sprint.id}"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["data"]).to include("nombre" => "Sprint 2", "estado" => "activo")
    end

    it "devuelve 404 si no existe" do
      get "/api/v1/sprints/999999"
      expect(response).to have_http_status(:not_found)
    end
  end
end
