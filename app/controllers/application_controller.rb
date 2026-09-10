class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  rescue_from ActionDispatch::Http::Parameters::ParseError do |e|
    render json: { errors: [ { status: "400", code: "malformed_request",
                              title: "No se puede procesar la solicitud",
                              detail: e.message, source: { pointer: "/body" } } ] }, status: :bad_request
  end

  private

  def error(status, code, detail, pointer)
    render json: { errors: [ { status: status.to_s, code: code, title: "No se puede procesar la solicitud",
                              detail: detail, source: { pointer: pointer } } ] }, status: status
  end

  def campo_readonly(payload, campos)
    campos.find { payload.key?(_1) }
  end

  def errores_validacion(registro)
    errores = registro.errors.map do |e|
      { status: "422", code: "validation_failed", title: "No se puede procesar la solicitud",
        detail: e.full_message, source: { pointer: "/#{e.attribute}" } }
    end
    render json: { errors: errores }, status: 422
  end
end
