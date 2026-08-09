# frozen_string_literal: true

module Api
  module V1
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      before_action :authenticate_api_user!

      attr_reader :current_user, :current_api_token

      private

      def authenticate_api_user!
        token_string = bearer_token
        @current_api_token = ApiToken.authenticate(token_string)
        @current_user = @current_api_token&.user

        return if @current_user

        render json: { error: "Unauthorized" }, status: :unauthorized
      end

      def bearer_token
        # Prefer standard Authorization: Bearer <token>
        authenticate_with_http_token { |token, _options| return token }

        # Fallback header used by some mobile clients
        request.headers["X-Api-Token"].presence
      end

      def render_validation_errors(record)
        render json: { errors: record.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end
end
