# Step definitions para features/agile/backlog.feature (@S-AGL-01..06).
# Peticiones HTTP via Rack::Test (World de cucumber-rails); respuestas en last_response.

World(FactoryBot::Syntax::Methods)

CAMPOS_NUMERICOS = %w[story_points cod_value cod_time_criticality cod_risk_reduction cod_duration].freeze

def normalizar(fila)
  fila.each_with_object({}) do |(clave, valor), acc|
    acc[clave] = CAMPOS_NUMERICOS.include?(clave) ? valor.to_i : valor
  end
end

def peticion_json(verbo, ruta, cuerpo)
  send(verbo, ruta, JSON.dump(cuerpo), "CONTENT_TYPE" => "application/json")
end

def respuesta_json
  JSON.parse(last_response.body)
end

Dado(/^que existe un workspace único de repostería con clave "REP"$/) do
  # Sin modelo Workspace aun: el API no depende de el (contrato no lo exige).
end

Dado(/^que el API \/api\/v1\/backlog_items está disponible$/) do
  # Ruta declarada en config/routes.rb; la verifica cada peticion.
end

Dado(/^que existe una historia de usuario en estado "([^"]+)"$/) do |estado|
  @historia = create(:backlog_item, estado: estado)
end

Dado(/^que existe una historia de usuario en estado "([^"]+)" con:$/) do |estado, tabla|
  @historia = create(:backlog_item, estado: estado, **normalizar(tabla.rows_hash))
end

Dado(/^que existen las siguientes historias de usuario:$/) do |tabla|
  @historias = tabla.hashes.map { |fila| create(:backlog_item, **normalizar(fila)) }
end

Cuando(/^envío una petición POST a \/api\/v1\/backlog_items con:$/) do |json|
  peticion_json(:post, "/api/v1/backlog_items", JSON.parse(json))
end

Cuando(/^envío una petición POST a \/api\/v1\/backlog_items con los campos:$/) do |tabla|
  peticion_json(:post, "/api/v1/backlog_items", normalizar(tabla.hashes.first))
end

Cuando(/^envío una petición PATCH a \/api\/v1\/backlog_items\/(\d+) con estado "([^"]+)"$/) do |_id, estado|
  peticion_json(:patch, "/api/v1/backlog_items/#{@historia.id}", "estado" => estado)
end

Cuando(/^envío una petición PATCH a \/api\/v1\/backlog_items\/(\d+) con:$/) do |_id, json|
  peticion_json(:patch, "/api/v1/backlog_items/#{@historia.id}", JSON.parse(json))
end

Cuando(/^envío una petición GET a \/api\/v1\/backlog_items$/) do
  get "/api/v1/backlog_items"
end

Entonces(/^la respuesta es (\d+)$/) do |status|
  expect(last_response.status).to eq(status.to_i)
end

Entonces(/^la historia creada tiene estado "([^"]+)"$/) do |estado|
  expect(respuesta_json["data"]["estado"]).to eq(estado)
end

Entonces(/^la respuesta incluye wsjf igual a ([0-9.]+)$/) do |wsjf|
  expect(respuesta_json["data"]["wsjf"]).to eq(wsjf.to_f)
end

Entonces(/^el error tiene código "([^"]+)"$/) do |codigo|
  expect(respuesta_json["errors"].first["code"]).to eq(codigo)
end

Entonces(/^la historia (?:queda|permanece) en estado "([^"]+)"$/) do |estado|
  expect(@historia.reload.estado).to eq(estado)
end

Entonces(/^la historia tiene título "([^"]+)"$/) do |titulo|
  expect(respuesta_json["data"]["titulo"]).to eq(titulo)
end

Entonces(/^la historia tiene descripcion "([^"]+)"$/) do |descripcion|
  expect(respuesta_json["data"]["descripcion"]).to eq(descripcion)
end

Entonces(/^la historia tiene prioridad "([^"]+)"$/) do |prioridad|
  expect(respuesta_json["data"]["prioridad"]).to eq(prioridad)
end

Entonces(/^la historia tiene story_points (\d+)$/) do |puntos|
  expect(respuesta_json["data"]["story_points"]).to eq(puntos.to_i)
end

Entonces(/^la respuesta devuelve las historias en este orden:$/) do |tabla|
  esperado = tabla.hashes.map { |fila| [fila["titulo"], fila["wsjf"].to_f] }
  obtenido = respuesta_json["data"].map { |h| [h["titulo"], h["wsjf"]] }
  expect(obtenido).to eq(esperado)
end