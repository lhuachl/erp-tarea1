# Step definitions para specs/reposteria/clientes.feature (@S-REP-20..28).
# Reutiliza peticion_json/respuesta_json y los steps "la respuesta es N" /
# "el error tiene código" de backlog_steps.rb.
# Los helpers propios usan prefijo "cliente" para no colisionar con sprints/backlog/inventario.

# Regla de unicidad (contrato repostería, invariante 3): la combinación (nombre, telefono)
# se compara tal como viene. Sin teléfono (nil) la unicidad no aplica. El teléfono vacío
# se normaliza a nil en el modelo.
#
# Guard cliente_con_pedidos: está dormido (Client no define #pedidos todavía). Para ejercitar
# el escenario S-REP-26 se define el método solo durante el escenario y se limpia en After.
PEDIDOS_ASOCIADOS_FALSOS = Object.new.tap do |relacion|
  def relacion.exists? = true
end

def activar_guard_pedidos
  Client.define_method(:pedidos) { PEDIDOS_ASOCIADOS_FALSOS }
end

def desactivar_guard_pedidos
  Client.remove_method(:pedidos) if Client.instance_methods(false).include?(:pedidos)
end

After { desactivar_guard_pedidos }

# Quita comillas dobles envolventes que la feature usa para denotar celdas string
# (p. ej. "" y "María López"); sin esto, "" viajaría como dos comillas.
def descomillar(valor)
  valor.to_s.gsub(/\A"|"\z/, "")
end

def normalizar_cliente(fila)
  fila.transform_values { descomillar(_1) }
end

# Registra el cliente creado con la etiqueta que usa la feature (1, 2, ...).
def anotar_cliente(cliente, etiqueta: nil)
  @clientes_por_etiqueta ||= {}
  @etiqueta_cliente ||= 1
  etiqueta ||= @etiqueta_cliente
  @clientes_por_etiqueta[etiqueta.to_s] = cliente
  @etiqueta_cliente = [ @etiqueta_cliente, etiqueta.to_i + 1 ].max
  @cliente = cliente
end

# Resuelve el id que nombra la feature (/clients/1) a un cliente realmente creado.
# Si la etiqueta no existe devuelve el id literal (p. ej. /99) para cubrir el 404.
def cliente_del_recurso(id)
  @clientes_por_etiqueta&.fetch(id.to_s, nil)&.id || id.to_i
end

Dado(/^que el API \/api\/v1\/clients está disponible$/) do
  expect(Rails.application.routes.recognize_path("/api/v1/clients")).to be_a(Hash)
end

Dado(/^que existe un cliente con nombre "([^"]+)" y teléfono "([^"]+)"$/) do |nombre, telefono|
  anotar_cliente(create(:client, nombre: nombre, telefono: telefono))
end

Dado(/^que existe un cliente con:$/) do |tabla|
  anotar_cliente(create(:client, **normalizar_cliente(tabla.rows_hash).symbolize_keys))
end

Dado(/^que existe un cliente sin pedidos asociados$/) do
  anotar_cliente(create(:client, nombre: "Cliente ocasional"))
end

Dado(/^que existe un cliente con pedidos asociados$/) do
  anotar_cliente(create(:client, nombre: "Cliente con pedidos"))
  activar_guard_pedidos
end

Dado(/^que existen los siguientes clientes:$/) do |tabla|
  @clientes_por_etiqueta = {}
  @etiqueta_cliente = 1
  tabla.hashes.each { |fila| anotar_cliente(create(:client, **normalizar_cliente(fila).symbolize_keys)) }
end

Cuando(/^envío una petición POST a \/api\/v1\/clients con:$/) do |json|
  @clientes_antes = Client.count
  peticion_json(:post, "/api/v1/clients", JSON.parse(json))
end

Cuando(/^envío una petición POST a \/api\/v1\/clients con los campos:$/) do |tabla|
  @clientes_antes = Client.count
  peticion_json(:post, "/api/v1/clients", normalizar_cliente(tabla.rows_hash).symbolize_keys)
end

Cuando(/^envío una petición PATCH a \/api\/v1\/clients\/(\d+) con:$/) do |id, json|
  peticion_json(:patch, "/api/v1/clients/#{cliente_del_recurso(id)}", JSON.parse(json))
end

Cuando(/^envío una petición DELETE a \/api\/v1\/clients\/(\d+)$/) do |id|
  delete "/api/v1/clients/#{cliente_del_recurso(id)}"
end

Cuando(/^envío una petición GET a \/api\/v1\/clients$/) do
  get "/api/v1/clients"
end

Cuando(/^envío una petición GET a \/api\/v1\/clients\?q=(\S+)$/) do |q|
  get "/api/v1/clients?q=#{q}"
end

Cuando(/^envío una petición GET a \/api\/v1\/clients\/(\d+)$/) do |id|
  get "/api/v1/clients/#{cliente_del_recurso(id)}"
end

Entonces(/^el cliente creado tiene nombre "([^"]+)"$/) do |nombre|
  expect(respuesta_json["data"]["nombre"]).to eq(nombre)
end

Entonces(/^el cliente creado tiene telefono "([^"]+)"$/) do |telefono|
  expect(respuesta_json["data"]["telefono"]).to eq(telefono)
end

Entonces(/^el cliente creado tiene email "([^"]+)"$/) do |email|
  expect(respuesta_json["data"]["email"]).to eq(email)
end

Entonces(/^el cliente creado no tiene (email|telefono)$/) do |campo|
  expect(respuesta_json["data"][campo]).to be_nil
end

Entonces(/^el cliente tiene nombre "([^"]+)"$/) do |nombre|
  expect(respuesta_json["data"]["nombre"]).to eq(nombre)
end

Entonces(/^el cliente tiene telefono "([^"]+)"$/) do |telefono|
  expect(respuesta_json["data"]["telefono"]).to eq(telefono)
end

Entonces(/^el cliente tiene direccion "([^"]+)"$/) do |direccion|
  expect(respuesta_json["data"]["direccion"]).to eq(direccion)
end

Entonces(/^no se crea ningún cliente$/) do
  expect(Client.count).to eq(@clientes_antes || 0)
end

Entonces(/^el cliente ya no existe$/) do
  expect(Client.exists?(@cliente.id)).to be(false)
end

Entonces(/^el cliente sigue existiendo$/) do
  expect(Client.exists?(@cliente.id)).to be(true)
end

Entonces(/^la respuesta devuelve (\d+) clientes$/) do |cantidad|
  expect(respuesta_json["data"].size).to eq(cantidad.to_i)
end

Entonces(/^la respuesta devuelve los clientes:$/) do |tabla|
  esperado = tabla.hashes.map { _1["nombre"] }
  expect(respuesta_json["data"].map { _1["nombre"] }).to eq(esperado)
end
