module Api
  module V1
    class DailySnapshotsController < ApplicationController
      CAMPOS_EDITABLES = %i[fecha puntos_restantes horas_restantes].freeze
      CAMPOS_READONLY = %w[id sprint_id].freeze

      def create
        sprint = Sprint.find_by(id: params["sprint_id"])
        return error(404, "not_found", "No existe el sprint", "/sprint_id") unless sprint

        payload = params.except("controller", "action", "sprint_id")
        if (campo = campo_readonly(payload, CAMPOS_READONLY))
          return error(422, "readonly_field", "El campo #{campo} es de solo lectura", "/#{campo}")
        end
        return error(422, "sprint_no_activo", "El sprint no está activo", "/sprint_id") unless sprint.estado == "activo"
        return error(422, "snapshot_duplicado", "Ya existe un snapshot para esa fecha", "/fecha") if sprint.daily_snapshots.exists?(fecha: payload["fecha"])

        snapshot = sprint.daily_snapshots.new(payload.permit(*CAMPOS_EDITABLES))
        return render json: { data: serializar(snapshot) }, status: :created if snapshot.save

        errores_validacion(snapshot)
      end

      private

      def serializar(snapshot)
        {
          id: snapshot.id, sprint_id: snapshot.sprint_id, fecha: snapshot.fecha,
          puntos_restantes: snapshot.puntos_restantes, horas_restantes: snapshot.horas_restantes
        }
      end
    end
  end
end
