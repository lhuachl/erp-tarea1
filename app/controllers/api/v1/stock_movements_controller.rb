module Api
  module V1
    class StockMovementsController < ApplicationController
      CAMPOS_CREACION = %i[tipo cantidad referencia].freeze
      CAMPOS_READONLY = %w[id material_id].freeze

      def create
        material = Material.find_by(id: params["material_id"])
        return error(404, "not_found", "No existe el insumo", "/material_id") unless material

        payload = params.except("controller", "action", "material_id")
        if (campo = campo_readonly(payload, CAMPOS_READONLY))
          return error(422, "readonly_field", "El campo #{campo} es de solo lectura", "/#{campo}")
        end

        movimiento = material.stock_movements.new(payload.permit(*CAMPOS_CREACION))
        case movimiento.registrar
        when :stock_insuficiente
          error(422, "stock_insuficiente", "El stock no alcanza para la salida", "/cantidad")
        when true
          render json: { data: serializar(movimiento) }, status: :created
        else
          errores_validacion(movimiento)
        end
      end

      private

      def serializar(movimiento)
        {
          id: movimiento.id, material_id: movimiento.material_id, tipo: movimiento.tipo,
          cantidad: movimiento.cantidad.to_f, referencia: movimiento.referencia, fecha: movimiento.fecha
        }
      end
    end
  end
end
