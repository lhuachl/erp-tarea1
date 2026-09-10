require "rails_helper"

RSpec.describe "Api::V1::Prioritizations", type: :request do
  def crear(titulo, prioridad:, **cod)
    create(:backlog_item, titulo: titulo, prioridad: prioridad, **cod)
  end

  def data
    JSON.parse(response.body)["data"]
  end

  describe "GET /api/v1/prioritization/ranking" do
    # @S-AGL-20: orden wsjf desc, desempate prioridad (alta > media > baja) e id asc
    it "ordena por wsjf desc y desempata por prioridad" do
      crear("Torta de cumpleaños", prioridad: "alta", cod_value: 8, cod_time_criticality: 5, cod_risk_reduction: 3, cod_duration: 2)
      crear("Reparto del turno tarde", prioridad: "media", cod_value: 8, cod_time_criticality: 5, cod_risk_reduction: 3, cod_duration: 2)
      crear("Inventario de harina", prioridad: "baja", cod_value: 8, cod_time_criticality: 5, cod_risk_reduction: 5, cod_duration: 2)

      get "/api/v1/prioritization/ranking"

      expect(response).to have_http_status(:ok)
      expect(data.map { |entrada| [ entrada["titulo"], entrada["wsjf"] ] }).to eq(
        [ [ "Inventario de harina", 9.0 ], [ "Torta de cumpleaños", 8.0 ], [ "Reparto del turno tarde", 8.0 ] ]
      )
    end

    # @S-AGL-20: empate total de wsjf → id ascendente
    it "desempata por id ascendente cuando wsjf y prioridad coinciden" do
      primero = crear("Cobrar pedidos pendientes", prioridad: "alta", cod_value: 4, cod_time_criticality: 3, cod_risk_reduction: 5, cod_duration: 2)
      segundo = crear("Sellar caja", prioridad: "alta", cod_value: 6, cod_time_criticality: 3, cod_risk_reduction: 3, cod_duration: 2)

      get "/api/v1/prioritization/ranking"

      expect(primero.id).to be < segundo.id
      expect(data.pluck("titulo")).to eq([ "Cobrar pedidos pendientes", "Sellar caja" ])
    end

    # Desempate alta > media > baja con wsjf idéntico: cubre los tres rangos.
    it "desempata los tres rangos de prioridad con el mismo wsjf" do
      crear("Baja", prioridad: "baja", cod_value: 10, cod_time_criticality: 0, cod_risk_reduction: 0, cod_duration: 2)
      crear("Alta", prioridad: "alta", cod_value: 10, cod_time_criticality: 0, cod_risk_reduction: 0, cod_duration: 2)
      crear("Media", prioridad: "media", cod_value: 10, cod_time_criticality: 0, cod_risk_reduction: 0, cod_duration: 2)

      get "/api/v1/prioritization/ranking"

      expect(data.pluck("titulo")).to eq([ "Alta", "Media", "Baja" ])
    end

    # @S-AGL-20: RankingEntry proyecta id, titulo, prioridad, estado y componentes CoD
    it "devuelve todos los campos del RankingEntry con el wsjf calculado" do
      item = crear("Torta de cumpleaños", prioridad: "alta",
                   cod_value: 8, cod_time_criticality: 5, cod_risk_reduction: 3, cod_duration: 2)

      get "/api/v1/prioritization/ranking"

      expect(data.first).to eq(
        "id" => item.id, "titulo" => "Torta de cumpleaños", "prioridad" => "alta", "estado" => "backlog",
        "cod_value" => 8, "cod_time_criticality" => 5, "cod_risk_reduction" => 3, "cod_duration" => 2,
        "wsjf" => 8.0, "cod_profile" => "standard"
      )
    end

    # @S-AGL-21: filtro ?estado= devuelve solo las historias de ese estado
    it "filtra por estado cuando viene el parámetro" do
      crear("Torta de cumpleaños", prioridad: "alta", cod_value: 8, cod_time_criticality: 5, cod_risk_reduction: 3, cod_duration: 2)
      crear("Cobrar pedidos pendientes", prioridad: "media", cod_value: 4, cod_time_criticality: 3, cod_risk_reduction: 5, cod_duration: 2, estado: "done")
      crear("Reparto del turno tarde", prioridad: "media", cod_value: 8, cod_time_criticality: 5, cod_risk_reduction: 3, cod_duration: 2, estado: "en_sprint")

      get "/api/v1/prioritization/ranking", params: { estado: "done" }

      expect(response).to have_http_status(:ok)
      expect(data.pluck("titulo", "wsjf")).to eq([ [ "Cobrar pedidos pendientes", 6.0 ] ])
    end

    it "sin filtro devuelve todas las historias de todos los estados" do
      crear("A", prioridad: "alta", cod_duration: 2, cod_value: 4, cod_time_criticality: 0, cod_risk_reduction: 0)
      crear("B", prioridad: "alta", cod_duration: 2, cod_value: 4, cod_time_criticality: 0, cod_risk_reduction: 0, estado: "listo")
      crear("C", prioridad: "alta", cod_duration: 2, cod_value: 4, cod_time_criticality: 0, cod_risk_reduction: 0, estado: "done")

      get "/api/v1/prioritization/ranking"

      expect(data.pluck("titulo")).to contain_exactly("A", "B", "C")
    end

    it "rechaza un estado fuera del enum con 422 validation_failed" do
      crear("A", prioridad: "alta", cod_duration: 2, cod_value: 4, cod_time_criticality: 0, cod_risk_reduction: 0)

      get "/api/v1/prioritization/ranking", params: { estado: "volando" }

      expect(response).to have_http_status(422)
      error = JSON.parse(response.body)["errors"].first
      expect(error["code"]).to eq("validation_failed")
      expect(error["source"]["pointer"]).to eq("/estado")
    end

    # @S-AGL-22: cod_duration = 0 → wsjf 0, intangible y al final
    it "manda al final del ranking la historia sin duración con wsjf 0 e intangible" do
      crear("Torta de cumpleaños", prioridad: "alta", cod_value: 8, cod_time_criticality: 5, cod_risk_reduction: 3, cod_duration: 2)
      crear("Ajustar receta", prioridad: "baja", cod_value: 1, cod_time_criticality: 1, cod_risk_reduction: 1, cod_duration: 10)
      crear("Sellar caja", prioridad: "alta", cod_value: 6, cod_time_criticality: 3, cod_risk_reduction: 3, cod_duration: 0)

      get "/api/v1/prioritization/ranking"

      expect(data.map { |entrada| [ entrada["titulo"], entrada["wsjf"], entrada["cod_profile"] ] }).to eq(
        [ [ "Torta de cumpleaños", 8.0, "standard" ], [ "Ajustar receta", 0.3, "intangible" ], [ "Sellar caja", 0.0, "intangible" ] ]
      )
    end

    # @S-AGL-25: parámetro wsjf del cliente se ignora; el GET no muta datos
    it "ignora el wsjf inyectado por el cliente y no modifica la historia" do
      item = crear("Torta de cumpleaños", prioridad: "alta", cod_value: 8, cod_time_criticality: 5, cod_risk_reduction: 3, cod_duration: 2)

      expect do
        get "/api/v1/prioritization/ranking", params: { wsjf: "999" }
      end.not_to(change { item.reload.attributes })

      expect(data.first["wsjf"]).to eq(8.0)
    end
  end

  describe "GET /api/v1/prioritization/matriz" do
    # @S-AGL-23: x = duration, y = CoD total, tamano = wsjf; incluye todas sin filtrar estado
    it "arma los puntos con x, y, tamano y perfil de todas las historias" do
      crear("Torta de cumpleaños", prioridad: "alta", cod_value: 8, cod_time_criticality: 5, cod_risk_reduction: 3, cod_duration: 2)
      crear("Cobrar pedidos pendientes", prioridad: "media", cod_value: 4, cod_time_criticality: 3, cod_risk_reduction: 2, cod_duration: 3, estado: "done")
      crear("Reparto del turno tarde", prioridad: "alta", cod_value: 12, cod_time_criticality: 8, cod_risk_reduction: 10, cod_duration: 1, estado: "listo")

      get "/api/v1/prioritization/matriz"

      expect(response).to have_http_status(:ok)
      expect(data).to eq(
        [
          { "titulo" => "Torta de cumpleaños", "x" => 2, "y" => 16, "tamano" => 8.0, "cod_profile" => "standard" },
          { "titulo" => "Cobrar pedidos pendientes", "x" => 3, "y" => 9, "tamano" => 3.0, "cod_profile" => "intangible" },
          { "titulo" => "Reparto del turno tarde", "x" => 1, "y" => 30, "tamano" => 30.0, "cod_profile" => "expedite" }
        ]
      )
    end

    it "devuelve arreglo vacío sin historias" do
      get "/api/v1/prioritization/matriz"
      expect(data).to eq([])
    end
  end

  describe "GET /api/v1/prioritization/perfil" do
    # @S-AGL-24: agrupa en los 4 cubos con el mismo orden del ranking
    it "agrupa las historias en expedite, fixed_date, standard e intangible" do
      crear("Torta de cumpleaños", prioridad: "alta", cod_value: 12, cod_time_criticality: 8, cod_risk_reduction: 10, cod_duration: 1)
      crear("Cobrar pedidos pendientes", prioridad: "media", cod_value: 2, cod_time_criticality: 8, cod_risk_reduction: 1, cod_duration: 4)
      crear("Reparto del turno tarde", prioridad: "media", cod_value: 6, cod_time_criticality: 3, cod_risk_reduction: 3, cod_duration: 2)
      crear("Ajustar receta", prioridad: "baja", cod_value: 1, cod_time_criticality: 1, cod_risk_reduction: 1, cod_duration: 10)

      get "/api/v1/prioritization/perfil"

      expect(response).to have_http_status(:ok)
      expect(data.keys).to eq(%w[expedite fixed_date standard intangible])
      expect(data.transform_values { |entradas| entradas.pluck("titulo") }).to eq(
        "expedite" => [ "Torta de cumpleaños" ],
        "fixed_date" => [ "Cobrar pedidos pendientes" ],
        "standard" => [ "Reparto del turno tarde" ],
        "intangible" => [ "Ajustar receta" ]
      )
    end

    it "devuelve los 4 cubos vacíos sin historias" do
      get "/api/v1/prioritization/perfil"
      expect(data).to eq("expedite" => [], "fixed_date" => [], "standard" => [], "intangible" => [])
    end

    # El cubo incluye RankingEntry completo, con el orden del ranking dentro del cubo.
    it "devuelve RankingEntry completos y ordenados dentro del cubo" do
      crear("Alta", prioridad: "alta", cod_value: 6, cod_time_criticality: 3, cod_risk_reduction: 3, cod_duration: 2)
      crear("Baja", prioridad: "baja", cod_value: 6, cod_time_criticality: 3, cod_risk_reduction: 3, cod_duration: 2)

      get "/api/v1/prioritization/perfil"

      expect(data["standard"].map { |entrada| [ entrada["titulo"], entrada["id"], entrada["wsjf"] ] }).to eq(
        [ [ "Alta", BacklogItem.find_by(titulo: "Alta").id, 6.0 ], [ "Baja", BacklogItem.find_by(titulo: "Baja").id, 6.0 ] ]
      )
    end
  end
end
