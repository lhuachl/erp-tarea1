module Api
  module V1
    class BacklogItemsController < ApplicationController
      CAMPOS_EDITABLES = %i[titulo descripcion story_points prioridad cod_value cod_time_criticality cod_risk_reduction cod_duration].freeze
      CAMPOS_ASIGNACION = %i[sprint_id].freeze
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
        if payload.key?("sprint_id") && !Sprint.exists?(id: payload["sprint_id"])
          return error(422, "validation_failed", "sprint_id no existe", "/sprint_id")
        end

        if payload.key?("estado")
          destino = payload["estado"]
          unless item.transicion_valida?(destino)
            return error(422, "invalid_transition", "No se puede pasar de #{item.estado} a #{destino}", "/estado")
          end
          if destino == "en_sprint" && item.estado == "listo" && payload["sprint_id"].blank?
            return error(422, "validation_failed", "sprint_id es obligatorio para pasar a en_sprint", "/sprint_id")
          end
          item.estado = destino
        end

        item.assign_attributes(payload.permit(*CAMPOS_EDITABLES, *CAMPOS_ASIGNACION))
        return render json: { data: serializar(item) } if item.save

        errores_validacion(item)
      end

      private

      def serializar(item)
        {
          id: item.id, titulo: item.titulo, descripcion: item.descripcion,
          story_points: item.story_points, prioridad: item.prioridad, estado: item.estado,
          cod_value: item.cod_value, cod_time_criticality: item.cod_time_criticality,
          cod_risk_reduction: item.cod_risk_reduction, cod_duration: item.cod_duration,
          wsjf: item.wsjf, cod_profile: item.cod_profile, sprint_id: item.sprint_id
        }
      end
    end
  end
end
