# frozen_string_literal: true

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      # Web (Devise session via Warden)
      user = env["warden"]&.user
      return user if user.present?

      # Mobile / Flutter: Bearer token as query param or header
      token = request.params["token"].presence ||
        extract_bearer_token ||
        request.headers["X-Api-Token"].presence

      if token.present?
        api_token = ApiToken.authenticate(token)
        return api_token.user if api_token&.user
      end

      reject_unauthorized_connection
    end

    def extract_bearer_token
      header = request.headers["Authorization"].to_s
      return unless header.start_with?("Bearer ")

      header.delete_prefix("Bearer ").strip.presence
    end
  end
end
