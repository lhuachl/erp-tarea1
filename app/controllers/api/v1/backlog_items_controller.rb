module Api
  module V1
    class BacklogItemsController < ApplicationController
      CAMPOS_EDITABLES = %i[titulo descripcion story_points prioridad cod_value cod_time_criticality cod_risk_reduction cod_duration].freeze
      CAMPOS_READONLY_CREATE = %w[id estado wsjf cod_profile].freeze
      CAMPOS_READONLY_UPDATE = %w[wsjf cod_profile].freeze

      def index
        render json: { data: BacklogItem.sorted.map { serializar(_1) } }
      end

      def create
        payload = params.except("controller", "action")
        if (campo = campo_readonly(payload, CAMPOS_READONLY_CREATE))
          return error(422, "readonly_field", "El campo #{campo} es de solo lectura", "/#{campo}")
        end

        item = BacklogItem.new(payload.permit(*CAMPOS_EDITABLES))
        return render json: { data: serializar(item) }, status: :created if item.save

        errores_validacion(item)
      end

      def update
        item = BacklogItem.find_by(id: params["id"])
        return error(404, "not_found", "No existe la historia", "/id") unless item

        payload = params.except("controller", "action", "id")
        if (campo = campo_readonly(payload, CAMPOS_READONLY_UPDATE))
          return error(422, "readonly_field", "El campo #{campo} es de solo lectura", "/#{campo}")
        end

        if payload.key?("estado")
          destino = payload["estado"]
          unless item.transicion_valida?(destino)
            return error(422, "invalid_transition", "No se puede pasar de #{item.estado} a #{destino}", "/estado")
          end
          item.estado = destino
        end

        item.assign_attributes(payload.permit(*CAMPOS_EDITABLES))
        return render json: { data: serializar(item) } if item.save

        errores_validacion(item)
      end

      private

      def campo_readonly(payload, campos)
        campos.find { payload.key?(_1) }
      end

      def serializar(item)
        {
          id: item.id, titulo: item.titulo, descripcion: item.descripcion,
          story_points: item.story_points, prioridad: item.prioridad, estado: item.estado,
          cod_value: item.cod_value, cod_time_criticality: item.cod_time_criticality,
          cod_risk_reduction: item.cod_risk_reduction, cod_duration: item.cod_duration,
          wsjf: item.wsjf, cod_profile: item.cod_profile
        }
      end

      def errores_validacion(item)
        errores = item.errors.map do |e|
          { status: "422", code: "validation_failed", title: "No se puede procesar la solicitud",
            detail: e.full_message, source: { pointer: "/#{e.attribute}" } }
        end
        render json: { errors: errores }, status: 422
      end

      def error(status, code, detail, pointer)
        render json: { errors: [{ status: status.to_s, code: code, title: "No se puede procesar la solicitud",
                                  detail: detail, source: { pointer: pointer } }] }, status: status
      end
    end
  end
end