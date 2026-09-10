module Api
  module V1
    class MaterialsController < ApplicationController
      CAMPOS_CREACION = %i[nombre unidad stock_actual stock_min costo_unitario].freeze
      CAMPOS_EDICION = %i[nombre unidad stock_min costo_unitario].freeze
      CAMPOS_READONLY_CREACION = %w[id critico].freeze
      CAMPOS_READONLY_EDICION = %w[id stock_actual critico].freeze

      def index
        materiales = Material.order(:id)
        materiales = materiales.select(&:critico?) if solo_criticos?
        render json: { data: materiales.map { serializar(_1) } }
      end

      def show
        material = Material.find_by(id: params["id"])
        return error(404, "not_found", "No existe el insumo", "/id") unless material

        render json: { data: serializar(material) }
      end

      def create
        payload = params.except("controller", "action")
        if (campo = campo_readonly(payload, CAMPOS_READONLY_CREACION))
          return error(422, "readonly_field", "El campo #{campo} es de solo lectura", "/#{campo}")
        end

        material = Material.new(payload.permit(*CAMPOS_CREACION))
        return render json: { data: serializar(material) }, status: :created if material.save

        error_de_material(material)
      end

      def update
        material = Material.find_by(id: params["id"])
        return error(404, "not_found", "No existe el insumo", "/id") unless material

        payload = params.except("controller", "action", "id")
        if (campo = campo_readonly(payload, CAMPOS_READONLY_EDICION))
          return error(422, "readonly_field", "El campo #{campo} es de solo lectura", "/#{campo}")
        end
        return render json: { data: serializar(material) } if material.update(payload.permit(*CAMPOS_EDICION))

        error_de_material(material)
      end

      private

      def solo_criticos?
        params[:solo_criticos] == "true"
      end

      def error_de_material(material)
        return error(422, "nombre_duplicado", "Ya existe un insumo con ese nombre", "/nombre") if material.errors.of_kind?(:nombre, :taken)

        errores_validacion(material)
      end

      def serializar(material)
        {
          id: material.id, nombre: material.nombre, unidad: material.unidad,
          stock_actual: material.stock_actual.to_f, stock_min: material.stock_min.to_f,
          costo_unitario: material.costo_unitario.to_f, critico: material.critico?
        }
      end
    end
  end
end
