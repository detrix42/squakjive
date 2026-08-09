# frozen_string_literal: true

module Api
  module V1
    class AuthController < BaseController
      skip_before_action :authenticate_api_user!, only: %i[login register]

      # POST /api/v1/auth/login
      # body: { username:, password:, device_name: optional }
      def login
        user = User.find_for_database_authentication(username: params[:username].to_s)
        unless user&.valid_password?(params[:password].to_s)
          return render json: { error: "Invalid username or password" }, status: :unauthorized
        end

        issue_token_response(user)
      end

      # POST /api/v1/auth/register
      # body: { username:, email:, password:, password_confirmation:, device_name: optional }
      def register
        user = User.new(register_params)
        if user.save
          issue_token_response(user, status: :created)
        else
          render_validation_errors(user)
        end
      end

      # DELETE /api/v1/auth/logout
      def logout
        current_api_token&.destroy
        head :no_content
      end

      private

      def register_params
        params.permit(:username, :email, :password, :password_confirmation)
      end

      def issue_token_response(user, status: :ok)
        token = user.api_tokens.create!(name: params[:device_name].presence || "mobile")
        render json: {
          token: token.token,
          user: UserSerializer.as_json(user)
        }, status: status
      end
    end
  end
end
