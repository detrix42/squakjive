module Api
  module V1

    class UploadsController < ApplicationController
      include Rails.application.routes.url_helpers

      protect_from_forgery with: :null_session
      # skip_before_action :log_params


      def create
        signed_id = params[:signed_id].to_s
        return render json: { error: "signed_id required" }, status: :bad_request if signed_id.blank?

        blob = ActiveStorage::Blob.resolve_from_sgid(signed_id)
        return render json: { error: "Blob not found" }, status: :not_found unless blob

        # If you want a real thumbnail, you can create a variant here:
        # preview = blob.variant(resize_to_limit: [800, 800]).processed
        # preview_url = rails_representation_path(preview, only_path: true)
        preview_url = url_for(blob) # relative path when used in a request context

        # Use only_path to avoid host inference issues
        download_url = rails_blob_path(blob, disposition: "attachment", only_path: true)


        render json: {
          filename: blob.filename.to_s,
          content_type: blob.content_type,
          byte_size: blob.byte_size,
          preview_url: preview_url,
          download_url: download_url
        }
      rescue => e
        Rails.logger.error("[UploadsController] #{e.class}: #{e.message}")
        render json: { error: "Failed to resolve upload" }, status: :internal_server_error
      end
    end
  end
end
