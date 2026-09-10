module Api
  module V1
    class PrioritizationsController < ApplicationController
      PERFILES = %w[expedite fixed_date standard intangible].freeze
      RANGO_PRIORIDAD = { "alta" => 0, "media" => 1, "baja" => 2 }.freeze

      def ranking
        return error(422, "validation_failed", "estado inválido", "/estado") if estado_invalido?

        items = params["estado"] ? BacklogItem.where(estado: params["estado"]) : BacklogItem.all
        render json: { data: ordenar(items).map { entrada(_1) } }
      end

      def matriz
        puntos = BacklogItem.order(:id).map do |item|
          { titulo: item.titulo, x: item.cod_duration,
            y: item.cod_value + item.cod_time_criticality + item.cod_risk_reduction,
            tamano: item.wsjf, cod_profile: item.cod_profile }
        end
        render json: { data: puntos }
      end

      def perfil
        agrupado = ordenar(BacklogItem.all).group_by(&:cod_profile)
        data = PERFILES.to_h { |perfil| [ perfil, (agrupado[perfil] || []).map { entrada(_1) } ] }
        render json: { data: data }
      end

      private

      def estado_invalido?
        params.key?("estado") && !BacklogItem::ESTADOS.include?(params["estado"])
      end

      def ordenar(items)
        items.sort_by { |item| [ -item.wsjf, RANGO_PRIORIDAD.fetch(item.prioridad, 3), item.id ] }
      end

      def entrada(item)
        { id: item.id, titulo: item.titulo, prioridad: item.prioridad, estado: item.estado,
          cod_value: item.cod_value, cod_time_criticality: item.cod_time_criticality,
          cod_risk_reduction: item.cod_risk_reduction, cod_duration: item.cod_duration,
          wsjf: item.wsjf, cod_profile: item.cod_profile }
      end
    end
  end
end
