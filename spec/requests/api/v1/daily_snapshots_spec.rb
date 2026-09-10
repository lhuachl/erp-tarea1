require "rails_helper"

RSpec.describe "Api::V1::DailySnapshots", type: :request do
  let(:sprint) { create(:sprint, estado: "activo", fecha_inicio: Date.current - 2, fecha_fin: Date.current + 5) }

  def payload(overrides = {})
    { fecha: Date.current, puntos_restantes: 21, horas_restantes: 40 }.merge(overrides)
  end

  describe "POST /api/v1/sprints/:sprint_id/daily_snapshots" do
    # @S-AGL-16
    it "crea el snapshot de un sprint activo" do
      post "/api/v1/sprints/#{sprint.id}/daily_snapshots", params: payload, as: :json
      expect(response).to have_http_status(:created)
      data = JSON.parse(response.body)["data"]
      expect(data).to include(
        "fecha" => Date.current.to_s, "puntos_restantes" => 21, "horas_restantes" => 40
      )
    end

    # @S-AGL-17: sprint no activo
    it "rechaza un snapshot sobre un sprint no activo" do
      planning = create(:sprint, estado: "planning")
      post "/api/v1/sprints/#{planning.id}/daily_snapshots", params: payload, as: :json
      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body)["errors"].first["code"]).to eq("sprint_no_activo")
    end

    # @S-AGL-17: fecha fuera del rango
    it "rechaza una fecha fuera del rango del sprint sin crear snapshot" do
      expect do
        post "/api/v1/sprints/#{sprint.id}/daily_snapshots", params: payload(fecha: sprint.fecha_fin + 1), as: :json
      end.not_to change(DailySnapshot, :count)
      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body)["errors"].first["code"]).to eq("validation_failed")
    end

    # @S-AGL-17: enteros negativos
    it "rechaza puntos u horas negativos" do
      post "/api/v1/sprints/#{sprint.id}/daily_snapshots", params: payload(puntos_restantes: -1), as: :json
      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body)["errors"].first["code"]).to eq("validation_failed")
    end

    # @S-AGL-18: duplicado deja intacto el existente
    it "rechaza un snapshot duplicado y conserva el existente" do
      existente = create(:daily_snapshot, sprint: sprint, fecha: Date.current, puntos_restantes: 21, horas_restantes: 40)
      post "/api/v1/sprints/#{sprint.id}/daily_snapshots", params: payload(puntos_restantes: 18), as: :json
      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body)["errors"].first["code"]).to eq("snapshot_duplicado")
      expect(existente.reload.puntos_restantes).to eq(21)
    end

    it "devuelve 404 si el sprint no existe" do
      post "/api/v1/sprints/999999/daily_snapshots", params: payload, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end
end
