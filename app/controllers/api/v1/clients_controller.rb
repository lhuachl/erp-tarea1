module Api
  module V1
    class ClientsController < ApplicationController
      CAMPOS = %i[nombre telefono email direccion notas].freeze

      def index
        clientes = Client.order(:id)
        if (texto = params[:q].presence)
          clientes = clientes.select { |cliente| normalizar(cliente.nombre).include?(normalizar(texto)) }
        end
        render json: { data: clientes.map { serializar(_1) } }
      end

      def show
        cliente = Client.find_by(id: params["id"])
        return error(404, "not_found", "No existe el cliente", "/id") unless cliente

        render json: { data: serializar(cliente) }
      end

      def create
        cliente = Client.new(params.permit(*CAMPOS))
        return render json: { data: serializar(cliente) }, status: :created if cliente.save

        error_de_cliente(cliente)
      end

      def update
        cliente = Client.find_by(id: params["id"])
        return error(404, "not_found", "No existe el cliente", "/id") unless cliente
        return render json: { data: serializar(cliente) } if cliente.update(params.permit(*CAMPOS))

        error_de_cliente(cliente)
      end

      def destroy
        cliente = Client.find_by(id: params["id"])
        return error(404, "not_found", "No existe el cliente", "/id") unless cliente
        return error(422, "cliente_con_pedidos", "El cliente tiene pedidos asociados", "/id") if cliente.tiene_pedidos?

        cliente.destroy
        head :no_content
      end

      private

      # Búsqueda parcial sin distinguir mayúsculas ni acentos ("lop" matchea "López").
      def normalizar(texto)
        ActiveSupport::Inflector.transliterate(texto).downcase
      end

      def error_de_cliente(cliente)
        if cliente.errors.of_kind?(:telefono, :taken)
          return error(422, "cliente_duplicado", "Ya existe un cliente con ese nombre y teléfono", "/telefono")
        end

        errores_validacion(cliente)
      end

      def serializar(cliente)
        {
          id: cliente.id, nombre: cliente.nombre, telefono: cliente.telefono,
          email: cliente.email, direccion: cliente.direccion, notas: cliente.notas
        }
      end
    end
  end
end
