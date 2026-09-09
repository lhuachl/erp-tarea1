class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  rescue_from ActionDispatch::Http::Parameters::ParseError do |e|
    render json: { errors: [{ status: "400", code: "malformed_request",
                              title: "No se puede procesar la solicitud",
                              detail: e.message, source: { pointer: "/body" } }] }, status: :bad_request
  end
end