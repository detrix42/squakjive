# frozen_string_literal: true

module Api
  module V1
    # Multipart file upload for mobile clients (token auth).
    # Prefer this over Trix/DirectUpload for the Flutter app.
    #
    # POST /api/v1/blobs
    #   multipart: file=<binary>
    #   optional:  preview_url=<string>  (client-generated thumb for video/pdf)
    class BlobsController < BaseController
      MAX_BYTES = 500.megabytes

      def create
        file = params[:file]
        return render json: { error: "file is required" }, status: :bad_request if file.blank?

        if file.respond_to?(:size) && file.size.to_i > MAX_BYTES
          return render json: { error: "File too large (max 500MB)" }, status: :unprocessable_entity
        end

        io = file.respond_to?(:tempfile) ? file.tempfile : file
        io.rewind if io.respond_to?(:rewind)

        blob = ActiveStorage::Blob.create_and_upload!(
          io: io,
          filename: file.original_filename.presence || "upload.bin",
          content_type: file.content_type.presence || "application/octet-stream",
          metadata: blob_metadata
        )

        # Analyze sync for images; async for large video/pdf so the request stays fast.
        if blob.image?
          blob.analyze
        else
          blob.analyze_later
        end

        render json: { blob: BlobSerializer.as_json(blob) }, status: :created
      rescue StandardError => e
        Rails.logger.error("[Api::V1::BlobsController] #{e.class}: #{e.message}")
        render json: { error: "Upload failed" }, status: :internal_server_error
      end

      private

      def blob_metadata
        meta = {}
        if params[:preview_url].present?
          meta[:preview_url] = params[:preview_url].to_s
        end
        meta
      end
    end
  end
end
