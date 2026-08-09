# frozen_string_literal: true

module Api
  module V1
    class DeviceTokensController < BaseController
      # POST /api/v1/device_tokens
      # { token, platform?, device_name? }
      def create
        token = params[:token].presence || params.dig(:device_token, :token)
        platform = params[:platform].presence || params.dig(:device_token, :platform) || "android"
        device_name = params[:device_name].presence || params.dig(:device_token, :device_name)

        if token.blank?
          return render json: { error: "token is required" }, status: :bad_request
        end

        record = DeviceToken.register!(
          user: current_user,
          token: token,
          platform: platform,
          device_name: device_name
        )

        render json: {
          device_token: {
            id: record.id,
            platform: record.platform,
            device_name: record.device_name,
            last_used_at: record.last_used_at
          }
        }, status: :created
      rescue ArgumentError => e
        render json: { error: e.message }, status: :unprocessable_entity
      rescue ActiveRecord::RecordInvalid => e
        render_validation_errors(e.record)
      end

      # DELETE /api/v1/device_token
      # body/query: { token } — unregister this device (logout)
      def destroy
        token = params[:token].presence
        if token.blank?
          return render json: { error: "token is required" }, status: :bad_request
        end

        DeviceToken.where(user_id: current_user.id, token: token).delete_all
        head :no_content
      end
    end
  end
end
