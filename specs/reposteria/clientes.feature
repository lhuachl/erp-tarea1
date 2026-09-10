# language: es
# Contrato de negocio del módulo Clientes del dominio repostería.
Característica: Gestión de clientes
  Como personal de la repostería
  Quiero crear, editar, buscar, listar y eliminar clientes
  Para reutilizarlos en el registro de pedidos sin duplicarlos

  Antecedentes:
    Dado que el API /api/v1/clients está disponible

  @S-REP-20
  Escenario: Crear un cliente con todos sus datos
    Cuando envío una petición POST a /api/v1/clients con:
      """json
      {
        "nombre": "María López",
        "telefono": "555-1234",
        "email": "maria@example.com",
        "direccion": "Calle Falsa 123",
        "notas": "Prefiere tortas de chocolate"
      }
      """
    Entonces la respuesta es 201
    Y el cliente creado tiene nombre "María López"
    Y el cliente creado tiene telefono "555-1234"
    Y el cliente creado tiene email "maria@example.com"

  @S-REP-21
  Escenario: Crear un cliente solo con su nombre
    Cuando envío una petición POST a /api/v1/clients con:
      """json
      {
        "nombre": "Cliente ocasional"
      }
      """
    Entonces la respuesta es 201
    Y el cliente creado tiene nombre "Cliente ocasional"
    Y el cliente creado no tiene email
    Y el cliente creado no tiene telefono

  @S-REP-22
  Esquema del escenario: Rechazar la creación de un cliente con datos inválidos
    Cuando envío una petición POST a /api/v1/clients con los campos:
      | nombre | <nombre> |
      | email  | <email>  |
    Entonces la respuesta es 422
    Y el error tiene código "validation_failed"
    Y no se crea ningún cliente

    Ejemplos:
      | nombre        | email             | motivo             |
      | ""            | maria@example.com | nombre obligatorio |
      | "María López" | sin-arroba        | formato de email   |
      | "María López" | maria@            | formato de email   |

  @S-REP-23
  Escenario: Rechazar un cliente duplicado por nombre y teléfono
    Dado que existe un cliente con nombre "María López" y teléfono "555-1234"
    Cuando envío una petición POST a /api/v1/clients con:
      """json
      {
        "nombre": "María López",
        "telefono": "555-1234",
        "email": "otra@example.com"
      }
      """
    Entonces la respuesta es 422
    Y el error tiene código "cliente_duplicado"
    Y no se crea ningún cliente

  @S-REP-24
  Escenario: Editar un cliente existente
    Dado que existe un cliente con:
      | nombre   | María López       |
      | telefono | 555-1234          |
      | email    | maria@example.com |
    Cuando envío una petición PATCH a /api/v1/clients/1 con:
      """json
      {
        "telefono": "555-9999",
        "direccion": "Calle Nueva 456"
      }
      """
    Entonces la respuesta es 200
    Y el cliente tiene nombre "María López"
    Y el cliente tiene telefono "555-9999"
    Y el cliente tiene direccion "Calle Nueva 456"

  @S-REP-25
  Escenario: Eliminar un cliente sin pedidos asociados
    Dado que existe un cliente sin pedidos asociados
    Cuando envío una petición DELETE a /api/v1/clients/1
    Entonces la respuesta es 204
    Y el cliente ya no existe

  @S-REP-26
  Escenario: Rechazar la eliminación de un cliente con pedidos asociados
    Dado que existe un cliente con pedidos asociados
    Cuando envío una petición DELETE a /api/v1/clients/1
    Entonces la respuesta es 422
    Y el error tiene código "cliente_con_pedidos"
    Y el cliente sigue existiendo

  @S-REP-27
  Escenario: Buscar clientes por nombre parcial sin distinguir mayúsculas
    Dado que existen los siguientes clientes:
      | nombre      | telefono |
      | María López | 555-1234 |
      | Pedro López | 555-5678 |
      | Ana Pérez   | 555-9012 |
    Cuando envío una petición GET a /api/v1/clients?q=lop
    Entonces la respuesta es 200
    Y la respuesta devuelve los clientes:
      | nombre      |
      | María López |
      | Pedro López |

  @S-REP-28
  Escenario: Listar clientes y obtener uno por id
    Dado que existen los siguientes clientes:
      | nombre      | telefono |
      | María López | 555-1234 |
      | Ana Pérez   | 555-9012 |
    Cuando envío una petición GET a /api/v1/clients
    Entonces la respuesta es 200
    Y la respuesta devuelve 2 clientes
    Cuando envío una petición GET a /api/v1/clients/1
    Entonces la respuesta es 200
    Y el cliente tiene nombre "María López"
    Cuando envío una petición GET a /api/v1/clients/99
    Entonces la respuesta es 404
    Y el error tiene código "not_found"

# contracts:
# - POST /api/v1/clients: crear cliente {nombre (obligatorio, no vacío), telefono (opcional), email (opcional, formato válido), direccion, notas}. Éxito 201 con el Cliente creado.
# - Validación de frontera: nombre obligatorio y no vacío; email opcional pero con formato válido si viene. Violación → 422 validation_failed y no se persiste nada.
# - Unicidad de cliente: no se permite duplicar la combinación (nombre, telefono). Duplicado → 422 cliente_duplicado y no se persiste nada. Sin teléfono, la unicidad no aplica.
# - PATCH /api/v1/clients/:id: edita campos editables (incluido nombre/email validados igual que en creación). Éxito 200 con el Cliente actualizado; inexistente → 404 not_found.
# - DELETE /api/v1/clients/:id: hard delete. Éxito 204 sin body; inexistente → 404 not_found.
# - GET /api/v1/clients?q=...: lista clientes; `q` opcional filtra por nombre parcial case-insensitive. Éxito 200.
# - GET /api/v1/clients/:id: obtiene un cliente por id. Éxito 200; inexistente → 404 not_found.
# - Frontera futura con Ventas (pedidos): si el cliente tiene pedidos asociados, DELETE → 422 cliente_con_pedidos y el cliente queda intacto. Mientras el módulo Ventas no materialice la asociación, el MVP hace hard delete y este guard permanece dormido (no bloquea la eliminación).
# - Frontera módulo repostería → clientes HTTP: shape { "data": { ...Cliente } } para éxitos y errores JSON API {"errors": [{status, code, title, detail, source}]}; códigos de este módulo: validation_failed, cliente_duplicado, cliente_con_pedidos, not_found.
