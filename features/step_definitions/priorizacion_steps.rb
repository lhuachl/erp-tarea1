# Step definitions para specs/agile/priorizacion.feature (@S-AGL-20..25).
# Cucumber lee los features desde specs/ (config/cucumber.yml) y carga estos steps
# vía --require features. Reutiliza la infraestructura Rack::Test del World.

PRIORIZACION_NUMERICOS = %w[cod_value cod_time_criticality cod_risk_reduction cod_duration story_points].freeze
PRIORIZACION_CUBOS = %w[expedite fixed_date standard intangible].freeze

def priorizacion_normalizar(fila)
  fila.each_with_object({}) do |(clave, valor), acc|
    acc[clave.to_sym] = PRIORIZACION_NUMERICOS.include?(clave) ? valor.to_i : valor
  end
end

def priorizacion_json
  JSON.parse(last_response.body)
end

Dado(/^que el API \/api\/v1\/prioritization está disponible$/) do
  expect(Rails.application.routes.recognize_path("/api/v1/prioritization/ranking")).to be_a(Hash)
end

Dado(/^que existen las siguientes historias priorizadas:$/) do |tabla|
  @historias = tabla.hashes.map { |fila| create(:backlog_item, **priorizacion_normalizar(fila)) }
end

Cuando(/^envío una petición GET a \/api\/v1\/prioritization\/ranking$/) do
  get "/api/v1/prioritization/ranking"
end

Cuando(/^envío una petición GET a \/api\/v1\/prioritization\/ranking con estado "([^"]+)"$/) do |estado|
  get "/api/v1/prioritization/ranking", { estado: estado }
end

Cuando(/^envío una petición GET a \/api\/v1\/prioritization\/ranking con el parámetro wsjf "([^"]+)"$/) do |wsjf|
  get "/api/v1/prioritization/ranking", { wsjf: wsjf }
end

Cuando(/^envío una petición GET a \/api\/v1\/prioritization\/matriz$/) do
  get "/api/v1/prioritization/matriz"
end

Cuando(/^envío una petición GET a \/api\/v1\/prioritization\/perfil$/) do
  get "/api/v1/prioritization/perfil"
end

Entonces(/^el ranking devuelve las historias en este orden:$/) do |tabla|
  esperado = tabla.hashes.map { |fila| [ fila["titulo"], fila["wsjf"].to_f, fila["cod_profile"] ] }
  obtenido = priorizacion_json["data"].map { |entrada| [ entrada["titulo"], entrada["wsjf"], entrada["cod_profile"] ] }
  expect(obtenido).to eq(esperado)
end

Entonces(/^el ranking devuelve las historias:$/) do |tabla|
  esperado = tabla.hashes.map { |fila| [ fila["titulo"], fila["wsjf"].to_f ] }
  obtenido = priorizacion_json["data"].map { |entrada| [ entrada["titulo"], entrada["wsjf"] ] }
  expect(obtenido).to eq(esperado)
end

Entonces(/^la entrada del ranking "([^"]+)" incluye los componentes CoD:$/) do |titulo, tabla|
  entrada = priorizacion_json["data"].find { |fila| fila["titulo"] == titulo }
  expect(entrada).not_to be_nil
  priorizacion_normalizar(tabla.hashes.first).each do |campo, valor|
    expect(entrada[campo.to_s]).to eq(valor)
  end
end

Entonces(/^el ranking devuelve para "([^"]+)" un wsjf igual a ([0-9.]+)$/) do |titulo, wsjf|
  entrada = priorizacion_json["data"].find { |fila| fila["titulo"] == titulo }
  expect(entrada["wsjf"]).to eq(wsjf.to_f)
end

Entonces(/^la matriz de cuadrante contiene los puntos:$/) do |tabla|
  obtenidos = priorizacion_json["data"].to_h { |punto| [ punto["titulo"], punto ] }
  expect(obtenidos.size).to eq(tabla.hashes.size)
  tabla.hashes.each do |fila|
    punto = obtenidos.fetch(fila["titulo"])
    expect(punto["x"]).to eq(fila["x"].to_i)
    expect(punto["y"]).to eq(fila["y"].to_i)
    expect(punto["tamano"]).to eq(fila["tamano"].to_f)
    expect(punto["cod_profile"]).to eq(fila["cod_profile"])
  end
end

Entonces(/^el perfil CoD agrupa las historias:$/) do |tabla|
  cubos = priorizacion_json["data"]
  expect(cubos.keys).to match_array(PRIORIZACION_CUBOS)
  tabla.hashes.each do |fila|
    titulos = cubos.fetch(fila["perfil"]).map { |entrada| entrada["titulo"] }
    esperados = fila["historias"].to_s.split(",").map(&:strip)
    expect(titulos).to match_array(esperados)
  end
end
