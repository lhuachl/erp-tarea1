# Step definitions para specs/agile/sprints.feature (@S-AGL-10..19).
# Cucumber lee los features desde specs/ (config/cucumber.yml) y carga estos steps
# vía --require features. Reutiliza peticion_json/respuesta_json de backlog_steps.rb.

CAMPOS_NUMERICOS_SNAPSHOT = %w[puntos_restantes horas_restantes].freeze
CAMPOS_FECHA = %w[fecha fecha_inicio fecha_fin].freeze

# La spec usa "" para denotar cadena vacía; Gherkin lo entrega literal.
def decodificar_vacio(valor)
  valor == '""' ? "" : valor
end

# Resuelve el vocabulario relativo de fechas: "hoy", "hoy + N", "hoy - N".
def resolver_fecha(valor)
  return valor if valor.respond_to?(:iso8601)
  return valor if valor.nil?

  caso = valor.to_s.strip
  return Date.current.iso8601 if caso == "hoy"

  coincidencia = caso.match(/\Ahoy\s*([+-])\s*(\d+)\z/)
  return caso unless coincidencia

  delta = coincidencia[2].to_i
  delta = -delta if coincidencia[1] == "-"
  (Date.current + delta).iso8601
end

def resolver_fechas(fila)
  fila.each_with_object({}) do |(clave, valor), acc|
    acc[clave] = CAMPOS_FECHA.include?(clave) ? resolver_fecha(valor) : valor
  end
end

def normalizar_sprint(fila)
  resolver_fechas(fila).transform_values { |valor| decodificar_vacio(valor) }
end

def normalizar_snapshot(fila)
  fila.each_with_object({}) do |(clave, valor), acc|
    acc[clave] = if CAMPOS_FECHA.include?(clave)
      resolver_fecha(valor)
    elsif CAMPOS_NUMERICOS_SNAPSHOT.include?(clave)
      valor.to_i
    else
      valor
    end
  end
end

# Registra el sprint creado con la etiqueta que usa la feature (1, 2, ...).
def anotar_sprint(sprint, etiqueta: nil)
  @sprints_por_etiqueta ||= {}
  @etiqueta_siguiente ||= 1
  etiqueta ||= @etiqueta_siguiente
  @sprints_por_etiqueta[etiqueta.to_s] = sprint
  @etiqueta_siguiente = [ @etiqueta_siguiente, etiqueta.to_i + 1 ].max
  @sprint = sprint
end

# Resuelve el id que nombra la feature: por nombre ("Sprint 2") o por etiqueta.
def sprint_del_recurso(id)
  por_nombre = (@sprints || []).find { |sprint| sprint.nombre == "Sprint #{id}" }
  por_nombre || @sprints_por_etiqueta&.fetch(id.to_s, nil) || Sprint.find(id)
end

Dado(/^que el API \/api\/v1\/sprints está disponible$/) do
  expect(Rails.application.routes.recognize_path("/api/v1/sprints")).to be_a(Hash)
end

# --- Creación de sprints (S-AGL-10, S-AGL-11) ---

Cuando(/^envío una petición POST a \/api\/v1\/sprints con:$/) do |json|
  peticion_json(:post, "/api/v1/sprints", resolver_fechas(JSON.parse(json)))
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

Dado(/^que existe un sprint en estado "([^"]+)"(?: del "([^"]+)" al "([^"]+)")?$/) do |estado, inicio, fin|
  attrs = { estado: estado }
  attrs[:fecha_inicio] = resolver_fecha(inicio) if inicio
  attrs[:fecha_fin] = resolver_fecha(fin) if fin
  anotar_sprint(create(:sprint, **attrs))
end

Dado(/^que existe un sprint en estado "([^"]+)" sin historias de usuario asignadas$/) do |estado|
  anotar_sprint(create(:sprint, estado: estado))
end

Dado(/^que ese sprint tiene una historia de usuario en estado "([^"]+)"(?: \(sin historias "done"\))?$/) do |estado|
  create(:backlog_item, estado: estado, sprint: @sprint)
end

Dado(/^que existe otro sprint en estado "([^"]+)" con una historia asignada$/) do |estado|
  anotar_sprint(create(:sprint, estado: estado))
  create(:backlog_item, estado: "en_sprint", sprint: @sprint)
end

# --- Transiciones de estado (S-AGL-12..15) ---

Cuando(/^envío una petición PATCH a \/api\/v1\/sprints\/(\d+) con estado "([^"]+)"$/) do |id, estado|
  peticion_json(:patch, "/api/v1/sprints/#{sprint_del_recurso(id).id}", "estado" => estado)
end

Entonces(/^el sprint(?: (\d+))? (?:queda|permanece) en estado "([^"]+)"$/) do |id, estado|
  sprint = id ? sprint_del_recurso(id) : @sprint
  expect(sprint.reload.estado).to eq(estado)
end

# --- Daily snapshots (S-AGL-16..18) ---

Dado(/^que ese sprint ya tiene un snapshot con fecha "([^"]+)"$/) do |fecha|
  @snapshot = create(:daily_snapshot, sprint: @sprint, fecha: resolver_fecha(fecha),
                                      puntos_restantes: 21, horas_restantes: 40)
end

Cuando(/^envío una petición POST a \/api\/v1\/sprints\/(\d+)\/daily_snapshots con:$/) do |id, json|
  peticion_json(:post, "/api/v1/sprints/#{sprint_del_recurso(id).id}/daily_snapshots", resolver_fechas(JSON.parse(json)))
end

Cuando(/^envío una petición POST a \/api\/v1\/sprints\/(\d+)\/daily_snapshots con los campos:$/) do |id, tabla|
  peticion_json(:post, "/api/v1/sprints/#{sprint_del_recurso(id).id}/daily_snapshots",
                normalizar_snapshot(tabla.hashes.first))
end

Entonces(/^el snapshot creado tiene fecha "([^"]+)"$/) do |fecha|
  expect(respuesta_json["data"]["fecha"]).to eq(resolver_fecha(fecha))
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
  @sprints = tabla.hashes.each_with_index.map do |fila, indice|
    anotar_sprint(create(:sprint, **resolver_fechas(fila).symbolize_keys), etiqueta: indice + 1)
  end
end

Cuando(/^envío una petición GET a \/api\/v1\/sprints$/) do
  get "/api/v1/sprints"
end

Cuando(/^envío una petición GET a \/api\/v1\/sprints\/(\d+)$/) do |id|
  get "/api/v1/sprints/#{sprint_del_recurso(id).id}"
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
