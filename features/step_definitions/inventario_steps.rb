# Step definitions para specs/reposteria/inventario.feature (@S-REP-01..10).
# Reutiliza peticion_json/respuesta_json y el step "la respuesta es N" de backlog_steps.rb.
# Los helpers propios usan prefijo "insumo"/"material" para no colisionar con sprints/backlog.

CAMPOS_NUMERICOS_INVENTARIO = %w[stock_actual stock_min costo_unitario cantidad].freeze

# Normaliza una fila de tabla Gherkin: los campos de stock/cantidad viajan como float.
def normalizar_insumo(fila)
  fila.each_with_object({}) do |(clave, valor), acc|
    acc[clave] = CAMPOS_NUMERICOS_INVENTARIO.include?(clave) ? valor.to_f : valor
  end
end

# Registra el insumo creado con la etiqueta que usa la feature (1, 2, ...).
def anotar_material(material, etiqueta: nil)
  @materiales_por_etiqueta ||= {}
  @etiqueta_material ||= 1
  etiqueta ||= @etiqueta_material
  @materiales_por_etiqueta[etiqueta.to_s] = material
  @etiqueta_material = [ @etiqueta_material, etiqueta.to_i + 1 ].max
  @material = material
end

# Resuelve el id que nombra la feature (/materials/1) a un insumo realmente creado.
def material_del_recurso(id)
  @materiales_por_etiqueta&.fetch(id.to_s, nil) || Material.find_by(id: id) || @material
end

def insumo_por_nombre(nombre)
  Material.find_by(nombre: nombre)
end

Dado(/^que el API \/api\/v1\/materials está disponible$/) do
  expect(Rails.application.routes.recognize_path("/api/v1/materials")).to be_a(Hash)
end

Dado(/^que existe el insumo "([^"]+)" con unidad "([^"]+)", stock ([0-9.]+), stock_min ([0-9.]+) y costo_unitario ([0-9.]+)$/) do |nombre, unidad, stock, stock_min, costo|
  anotar_material(create(:material, nombre: nombre, unidad: unidad, stock_actual: stock,
                         stock_min: stock_min, costo_unitario: costo))
end

Dado(/^que existen los siguientes insumos:$/) do |tabla|
  @materiales_por_etiqueta = {}
  @etiqueta_material = 1
  tabla.hashes.each { |fila| anotar_material(create(:material, **normalizar_insumo(fila).symbolize_keys)) }
end

Cuando(/^envío una petición POST a \/api\/v1\/materials con:$/) do |json|
  peticion_json(:post, "/api/v1/materials", JSON.parse(json))
end

Cuando(/^envío una petición POST a \/api\/v1\/materials con los campos:$/) do |tabla|
  peticion_json(:post, "/api/v1/materials", normalizar_insumo(tabla.hashes.first).symbolize_keys)
end

Cuando(/^envío una petición PATCH a \/api\/v1\/materials\/(\d+) con:$/) do |id, json|
  peticion_json(:patch, "/api/v1/materials/#{material_del_recurso(id).id}", JSON.parse(json))
end

Cuando(/^envío una petición GET a \/api\/v1\/materials$/) do
  get "/api/v1/materials"
end

Cuando(/^envío una petición GET a \/api\/v1\/materials\/(\d+)$/) do |id|
  get "/api/v1/materials/#{material_del_recurso(id).id}"
end

Cuando(/^envío una petición GET a \/api\/v1\/materials\?solo_criticos=true$/) do
  get "/api/v1/materials?solo_criticos=true"
end

Cuando(/^envío una petición POST a \/api\/v1\/materials\/(\d+)\/stock_movements con:$/) do |id, json|
  peticion_json(:post, "/api/v1/materials/#{material_del_recurso(id).id}/stock_movements", JSON.parse(json))
end

Cuando(/^envío una petición POST a \/api\/v1\/materials\/(\d+)\/stock_movements con los campos:$/) do |id, tabla|
  peticion_json(:post, "/api/v1/materials/#{material_del_recurso(id).id}/stock_movements",
                normalizar_insumo(tabla.hashes.first).symbolize_keys)
end

Entonces(/^el insumo creado tiene nombre "([^"]+)"$/) do |nombre|
  expect(respuesta_json["data"]["nombre"]).to eq(nombre)
end

Entonces(/^el insumo creado tiene unidad "([^"]+)"$/) do |unidad|
  expect(respuesta_json["data"]["unidad"]).to eq(unidad)
end

Entonces(/^el insumo creado tiene stock_actual ([0-9.]+)$/) do |valor|
  expect(respuesta_json["data"]["stock_actual"]).to eq(valor.to_f)
end

Entonces(/^el insumo creado tiene stock_min ([0-9.]+)$/) do |valor|
  expect(respuesta_json["data"]["stock_min"]).to eq(valor.to_f)
end

Entonces(/^el insumo creado tiene costo_unitario ([0-9.]+)$/) do |valor|
  expect(respuesta_json["data"]["costo_unitario"]).to eq(valor.to_f)
end

Entonces(/^no se crea ningún insumo$/) do
  expect(Material.count).to eq(0)
end

Entonces(/^no se crea un insumo duplicado$/) do
  expect(Material.where(nombre: "Harina").count).to eq(1)
end

Entonces(/^el insumo "([^"]+)" tiene stock ([0-9.]+)$/) do |nombre, valor|
  expect(insumo_por_nombre(nombre).stock_actual.to_f).to eq(valor.to_f)
end

Entonces(/^el insumo "([^"]+)" conserva stock ([0-9.]+)$/) do |nombre, valor|
  expect(insumo_por_nombre(nombre).reload.stock_actual.to_f).to eq(valor.to_f)
end

Entonces(/^el insumo conserva stock ([0-9.]+)$/) do |valor|
  expect(@material.reload.stock_actual.to_f).to eq(valor.to_f)
end

Entonces(/^no se registra ningún movimiento$/) do
  expect(StockMovement.count).to eq(0)
end

Entonces(/^la respuesta devuelve solo los insumos:$/) do |tabla|
  esperado = tabla.hashes.map { _1["nombre"] }
  expect(respuesta_json["data"].map { _1["nombre"] }).to eq(esperado)
end

Entonces(/^la respuesta devuelve los insumos:$/) do |tabla|
  esperado = tabla.hashes.map { |fila| [ fila["nombre"], fila["stock_actual"].to_f ] }
  obtenido = respuesta_json["data"].map { |material| [ material["nombre"], material["stock_actual"] ] }
  expect(obtenido).to eq(esperado)
end

Entonces(/^el insumo tiene nombre "([^"]+)"$/) do |nombre|
  expect(respuesta_json["data"]["nombre"]).to eq(nombre)
end

Entonces(/^el insumo tiene unidad "([^"]+)"$/) do |unidad|
  expect(respuesta_json["data"]["unidad"]).to eq(unidad)
end

Entonces(/^el insumo tiene stock_actual ([0-9.]+)$/) do |valor|
  expect(respuesta_json["data"]["stock_actual"]).to eq(valor.to_f)
end

Entonces(/^el insumo tiene stock_min ([0-9.]+)$/) do |valor|
  expect(respuesta_json["data"]["stock_min"]).to eq(valor.to_f)
end

Entonces(/^el insumo tiene costo_unitario ([0-9.]+)$/) do |valor|
  expect(respuesta_json["data"]["costo_unitario"]).to eq(valor.to_f)
end
