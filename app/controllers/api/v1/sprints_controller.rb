module Api
  module V1
    class SprintsController < ApplicationController
      CAMPOS_EDITABLES = %i[nombre objetivo fecha_inicio fecha_fin].freeze
      CAMPOS_FECHA = %w[fecha_inicio fecha_fin].freeze
      CAMPOS_READONLY_CREATE = %w[id estado].freeze
      CAMPOS_READONLY_UPDATE = %w[id].freeze

      def index
        render json: { data: Sprint.order(:id).map { serializar(_1) } }
      end

      def show
        sprint = Sprint.find_by(id: params["id"])
        return error(404, "not_found", "No existe el sprint", "/id") unless sprint

        render json: { data: serializar(sprint) }
      end

      def create
        payload = params.except("controller", "action")
        if (campo = campo_readonly(payload, CAMPOS_READONLY_CREATE))
          return error(422, "readonly_field", "El campo #{campo} es de solo lectura", "/#{campo}")
        end

        sprint = Sprint.new(payload.permit(*CAMPOS_EDITABLES))
        return render json: { data: serializar(sprint) }, status: :created if sprint.save

        errores_validacion(sprint)
      end

      def update
        sprint = Sprint.find_by(id: params["id"])
        return error(404, "not_found", "No existe el sprint", "/id") unless sprint

        payload = params.except("controller", "action", "id")
        if (campo = campo_readonly(payload, CAMPOS_READONLY_UPDATE))
          return error(422, "readonly_field", "El campo #{campo} es de solo lectura", "/#{campo}")
        end
        if sprint.estado != "planning" && (campo = campo_readonly(payload, CAMPOS_FECHA))
          return error(422, "validation_failed", "El campo #{campo} solo se edita en planning", "/#{campo}")
        end

        if payload.key?("estado")
          destino = payload["estado"]
          unless sprint.transicion_valida?(destino)
            return error(422, "invalid_transition", "No se puede pasar de #{sprint.estado} a #{destino}", "/estado")
          end
          if activar?(sprint, destino)
            return error(422, "sprint_activo_duplicado", "Ya existe un sprint activo", "/estado") if otro_sprint_activo?(sprint)
            return error(422, "sprint_vacio", "El sprint no tiene historias en_sprint", "/estado") if sprint.historias_en_sprint.none?
          end
          sprint.estado = destino
        end

        sprint.assign_attributes(payload.permit(*CAMPOS_EDITABLES))
        return render json: { data: serializar(sprint) } if sprint.save

        errores_validacion(sprint)
      end

      private

      def activar?(sprint, destino)
        destino == "activo" && sprint.estado != "activo"
      end

      def otro_sprint_activo?(sprint)
        Sprint.where(estado: "activo").where.not(id: sprint.id).exists?
      end

      def serializar(sprint)
        {
          id: sprint.id, nombre: sprint.nombre, objetivo: sprint.objetivo,
          fecha_inicio: sprint.fecha_inicio, fecha_fin: sprint.fecha_fin, estado: sprint.estado
        }
      end
    end
  end
end
