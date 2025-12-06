class Api::BaseController < ApplicationController
  include ApiAuthentication

  skip_before_action :verify_authenticity_token
  skip_before_action :require_account
  skip_before_action :require_authentication

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :record_invalid
  rescue_from ArgumentError, with: :bad_request
  rescue_from StandardError, with: :internal_server_error

  private
    def record_not_found
      render json: { error: "not_found", message: "Resource not found" }, status: :not_found
    end

    def record_invalid(exception)
      render json: { error: "validation_error", message: exception.message }, status: :unprocessable_entity
    end

    def bad_request(exception)
      render json: { error: "bad_request", message: exception.message }, status: :bad_request
    end

    def internal_server_error(exception)
      Rails.logger.error "API Error: #{exception.class} - #{exception.message}"
      Rails.logger.error exception.backtrace.join("\n")
      
      render json: { 
        error: "internal_server_error", 
        message: Rails.env.development? ? exception.message : "An internal error occurred"
      }, status: :internal_server_error
    end

    def render_json_error(message, status: :unprocessable_entity)
      render json: { error: "error", message: message }, status: status
    end
end
