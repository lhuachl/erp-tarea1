# Step definitions para features/agile/sprints.feature (@S-AGL-10..19).
# Reutiliza peticion_json/respuesta_json de backlog_steps.rb (definidos en Object).
# Helpers propios con prefijo para no colisionar con los de backlog.

CAMPOS_NUMERICOS_SNAPSHOT = %w[puntos_restantes horas_restantes].freeze

def normalizar_snapshot(fila)
  fila.each_with_object({}) do |(clave, valor), acc|
    acc[clave] = CAMPOS_NUMERICOS_SNAPSHOT.include?(clave) ? valor.to_i : valor
  end
end

# La spec usa "" para denotar cadena vacía en la tabla; Gherkin lo entrega literal.
def normalizar_sprint(fila)
  fila.transform_values { |valor| valor == '""' ? "" : valor }
end

Dado(/^que el API \/api\/v1\/sprints está disponible$/) do
  # Ruta declarada en config/routes.rb; la verifica cada petición.
end

# --- Creación de sprints (S-AGL-10, S-AGL-11) ---

Cuando(/^envío una petición POST a \/api\/v1\/sprints con:$/) do |json|
  peticion_json(:post, "/api/v1/sprints", JSON.parse(json))
end

Cuando(/^envío una petición POST a \/api\/v1\/sprints con los campos:$/) do |tabla|
  peticion_json(:post, "/api/v1/sprints", normalizar_sprint(tabla.hashes.first))
end

Entonces(/^el sprint creado tiene nombre "([^"]+)"$/) do |nombre|
  expect(respuesta_json["data"]["nombre"]).to eq(nombre)
end

Entonces(/^el sprint creado tiene estado "([^"]+)"$/) do |estado|
  expect(respuesta_json["data"]["estado"]).to eq(estado)
end

Entonces(/^no se crea ningún sprint$/) do
  expect(Sprint.count).to eq(0)
end

# --- Fixtures de sprints (S-AGL-12..19) ---

Dado(/^que existe un sprint en estado "([^"]+)"(?: del (\d{4}-\d{2}-\d{2}) al (\d{4}-\d{2}-\d{2}))?$/) do |estado, inicio, fin|
  @sprint = if inicio
    create(:sprint, estado: estado, fecha_inicio: inicio, fecha_fin: fin)
  else
    create(:sprint, estado: estado)
  end
end

Dado(/^que existe un sprint en estado "([^"]+)" sin historias de usuario asignadas$/) do |estado|
  @sprint = create(:sprint, estado: estado)
end

Dado(/^que ese sprint tiene una historia de usuario en estado "([^"]+)"(?: \(sin historias "done"\))?$/) do |estado|
  create(:backlog_item, estado: estado, sprint: @sprint)
end

Dado(/^que existe otro sprint en estado "([^"]+)" con una historia asignada$/) do |estado|
  @sprint = create(:sprint, estado: estado)
  create(:backlog_item, estado: "en_sprint", sprint: @sprint)
end

# --- Transiciones de estado (S-AGL-12..15) ---

Cuando(/^envío una petición PATCH a \/api\/v1\/sprints\/(\d+) con estado "([^"]+)"$/) do |_id, estado|
  peticion_json(:patch, "/api/v1/sprints/#{@sprint.id}", "estado" => estado)
end

Entonces(/^el sprint(?: \d+)? (?:queda|permanece) en estado "([^"]+)"$/) do |estado|
  expect(@sprint.reload.estado).to eq(estado)
end

# --- Daily snapshots (S-AGL-16..18) ---

Dado(/^que hoy es el (\d{4}-\d{2}-\d{2})$/) do |_fecha|
  # Marcador del escenario: la app valida el rango del sprint, no la fecha real.
end

Dado(/^que ese sprint ya tiene un snapshot con fecha "([^"]+)"$/) do |fecha|
  @snapshot = create(:daily_snapshot, sprint: @sprint, fecha: fecha, puntos_restantes: 21, horas_restantes: 40)
end

Cuando(/^envío una petición POST a \/api\/v1\/sprints\/(\d+)\/daily_snapshots con:$/) do |_id, json|
  peticion_json(:post, "/api/v1/sprints/#{@sprint.id}/daily_snapshots", JSON.parse(json))
end

Cuando(/^envío una petición POST a \/api\/v1\/sprints\/(\d+)\/daily_snapshots con los campos:$/) do |_id, tabla|
  peticion_json(:post, "/api/v1/sprints/#{@sprint.id}/daily_snapshots", normalizar_snapshot(tabla.hashes.first))
end

Entonces(/^el snapshot creado tiene fecha "([^"]+)"$/) do |fecha|
  expect(respuesta_json["data"]["fecha"]).to eq(fecha)
end

Entonces(/^el snapshot creado tiene puntos_restantes (\d+)$/) do |puntos|
  expect(respuesta_json["data"]["puntos_restantes"]).to eq(puntos.to_i)
end

Entonces(/^el snapshot creado tiene horas_restantes (\d+)$/) do |horas|
  expect(respuesta_json["data"]["horas_restantes"]).to eq(horas.to_i)
end

Entonces(/^no se crea ningún snapshot$/) do
  expect(DailySnapshot.count).to eq(0)
end

Entonces(/^el snapshot existente mantiene puntos_restantes (\d+)$/) do |puntos|
  expect(@snapshot.reload.puntos_restantes).to eq(puntos.to_i)
end

# --- Listado y detalle (S-AGL-19) ---

Dado(/^que existen los siguientes sprints:$/) do |tabla|
  @sprints = tabla.hashes.map { |fila| create(:sprint, **fila.symbolize_keys) }
end

Cuando(/^envío una petición GET a \/api\/v1\/sprints$/) do
  get "/api/v1/sprints"
end

Cuando(/^envío una petición GET a \/api\/v1\/sprints\/(\d+)$/) do |id|
  objetivo = @sprints ? @sprints[id.to_i - 1] : Sprint.find(id)
  get "/api/v1/sprints/#{objetivo.id}"
end

Entonces(/^la respuesta devuelve los sprints:$/) do |tabla|
  esperado = tabla.hashes.map { |fila| [ fila["nombre"], fila["estado"] ] }
  obtenido = respuesta_json["data"].map { |sprint| [ sprint["nombre"], sprint["estado"] ] }
  expect(obtenido).to eq(esperado)
end

Entonces(/^el sprint tiene nombre "([^"]+)"$/) do |nombre|
  expect(respuesta_json["data"]["nombre"]).to eq(nombre)
end

Entonces(/^el sprint tiene estado "([^"]+)"$/) do |estado|
  expect(respuesta_json["data"]["estado"]).to eq(estado)
end
