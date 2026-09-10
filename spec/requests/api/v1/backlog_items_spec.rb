require "rails_helper"

RSpec.describe "Api::V1::BacklogItems", type: :request do
  describe "POST /api/v1/backlog_items" do
    # Contrato tabla de errores: JSON malformado -> 400 malformed_request
    it "devuelve 400 malformed_request con shape JSON API si el body no es JSON" do
      post "/api/v1/backlog_items", params: "{esto no es json", headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:bad_request)
      error = JSON.parse(response.body)["errors"].first
      expect(error).to include("status" => "400", "code" => "malformed_request")
    end

    # Contrato invariante 1: campos calculados nunca se aceptan del cliente
    %w[wsjf cod_profile].each do |campo|
      it "rechaza #{campo} con 422 readonly_field" do
        post "/api/v1/backlog_items", params: { titulo: "Cobrar", story_points: 3, campo => 99 }, as: :json
        expect(response).to have_http_status(422)
        error = JSON.parse(response.body)["errors"].first
        expect(error["code"]).to eq("readonly_field")
        expect(error["source"]["pointer"]).to eq("/#{campo}")
      end
    end

    # Contrato invariante 6: POST no acepta estado (ni id)
    %w[id estado].each do |campo|
      it "rechaza #{campo} con 422 readonly_field" do
        post "/api/v1/backlog_items", params: { titulo: "Cobrar", story_points: 3, campo => "x" }, as: :json
        expect(response).to have_http_status(422)
        expect(JSON.parse(response.body)["errors"].first["code"]).to eq("readonly_field")
      end
    end

    it "devuelve 422 validation_failed con shape JSON API si story_points es 0" do
      post "/api/v1/backlog_items", params: { titulo: "Cobrar", story_points: 0, prioridad: "media" }, as: :json
      expect(response).to have_http_status(422)
      error = JSON.parse(response.body)["errors"].first
      expect(error).to include("status" => "422", "code" => "validation_failed")
      expect(error["source"]["pointer"]).to eq("/story_points")
    end

    it "no crea registro si la validacion falla" do
      expect do
        post "/api/v1/backlog_items", params: { titulo: "", story_points: 3 }, as: :json
      end.not_to change(BacklogItem, :count)
    end
  end

  describe "PATCH /api/v1/backlog_items/:id" do
    it "rechaza wsjf con 422 readonly_field" do
      item = create(:backlog_item)
      patch "/api/v1/backlog_items/#{item.id}", params: { wsjf: 99 }, as: :json
      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body)["errors"].first["code"]).to eq("readonly_field")
    end

    it "rechaza cod_profile con 422 readonly_field" do
      item = create(:backlog_item)
      patch "/api/v1/backlog_items/#{item.id}", params: { cod_profile: "expedite" }, as: :json
      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body)["errors"].first["code"]).to eq("readonly_field")
    end

    it "devuelve 404 not_found si la historia no existe" do
      patch "/api/v1/backlog_items/999", params: { titulo: "x" }, as: :json
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)["errors"].first["code"]).to eq("not_found")
    end

    # @S-AGL-04: transicion invalida deja el estado intacto
    it "transicion invalida devuelve 422 y no cambia el estado" do
      item = create(:backlog_item, estado: "backlog")
      patch "/api/v1/backlog_items/#{item.id}", params: { estado: "done" }, as: :json
      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body)["errors"].first["code"]).to eq("invalid_transition")
      expect(item.reload.estado).to eq("backlog")
    end
  end

  describe "PATCH /api/v1/backlog_items/:id (asignación a sprint)" do
    # Contrato Backlog actualizado: listo -> en_sprint exige un sprint_id válido
    it "asigna el sprint al pasar a en_sprint" do
      item = create(:backlog_item, estado: "listo")
      sprint = create(:sprint)

      patch "/api/v1/backlog_items/#{item.id}", params: { estado: "en_sprint", sprint_id: sprint.id }, as: :json
      expect(response).to have_http_status(:ok)
      expect(item.reload.estado).to eq("en_sprint")
      expect(item.sprint_id).to eq(sprint.id)
    end

    it "rechaza en_sprint sin sprint_id" do
      item = create(:backlog_item, estado: "listo")
      patch "/api/v1/backlog_items/#{item.id}", params: { estado: "en_sprint" }, as: :json
      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body)["errors"].first["code"]).to eq("validation_failed")
      expect(item.reload.estado).to eq("listo")
    end

    it "rechaza un sprint_id inexistente" do
      item = create(:backlog_item, estado: "listo")
      patch "/api/v1/backlog_items/#{item.id}", params: { estado: "en_sprint", sprint_id: 999_999 }, as: :json
      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body)["errors"].first["source"]["pointer"]).to eq("/sprint_id")
      expect(item.reload.estado).to eq("listo")
    end
  end
end
