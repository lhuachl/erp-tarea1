require "rails_helper"

RSpec.describe "Api::V1::StockMovements", type: :request do
  let(:material) { create(:material, nombre: "Harina", stock_actual: 10, stock_min: 2) }

  describe "POST /api/v1/materials/:material_id/stock_movements" do
    # @S-REP-04
    { "entrada" => [ 5, 15 ], "salida" => [ 4, 6 ], "ajuste" => [ 7, 7 ] }.each do |tipo, (cantidad, stock_final)|
      it "registra #{tipo} y deja el stock en #{stock_final}" do
        expect do
          post "/api/v1/materials/#{material.id}/stock_movements",
               params: { tipo: tipo, cantidad: cantidad, referencia: "ref" }, as: :json
        end.to change(StockMovement, :count).by(1)
        expect(response).to have_http_status(:created)
        expect(material.reload.stock_actual).to eq(stock_final)
      end
    end

    # @S-REP-05
    it "rechaza una salida que dejaría stock negativo sin registrar movimiento" do
      expect do
        post "/api/v1/materials/#{material.id}/stock_movements",
             params: { tipo: "salida", cantidad: 12, referencia: "producción" }, as: :json
      end.not_to change(StockMovement, :count)
      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body)["errors"].first["code"]).to eq("stock_insuficiente")
      expect(material.reload.stock_actual).to eq(10)
    end

    # @S-REP-06
    { "cantidad cero" => { tipo: "entrada", cantidad: 0 },
      "cantidad negativa" => { tipo: "salida", cantidad: -3 },
      "tipo inválido" => { tipo: "transferencia", cantidad: 5 } }.each do |motivo, params|
      it "rechaza #{motivo} sin registrar movimiento" do
        expect do
          post "/api/v1/materials/#{material.id}/stock_movements", params: params, as: :json
        end.not_to change(StockMovement, :count)
        expect(response).to have_http_status(422)
        expect(JSON.parse(response.body)["errors"].first["code"]).to eq("validation_failed")
        expect(material.reload.stock_actual).to eq(10)
      end
    end

    it "devuelve 404 si el insumo no existe" do
      post "/api/v1/materials/999999/stock_movements", params: { tipo: "entrada", cantidad: 1 }, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end
end
