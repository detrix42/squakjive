class ActiveStorage::BlobsController < ActiveStorage::BaseController
  include Rails.application.routes.url_helpers

  # def default_url_options
  #    {
  #     host: "squakjive.novasector.net",
  #     protocol: "https"
  #    }
  # end

  def analyze
    Rails.logger.debug "Analyze endpoint called with SGID: #{params[:sgid]}"
    begin
      blob = ActiveStorage::Blob.resolve_from_sgid(params[:sgid])
      if blob.nil?
        Rails.logger.error "Blob not found for SGID: #{params[:sgid]}"
        render json: { error: "Blob not found" }, status: :not_found
        return
      end
      Rails.logger.debug "Blob found: ID: #{blob.id}, Filename: #{blob.filename}, ContentType: #{blob.content_type}"
      blob.analyze
      Rails.logger.debug "Blob analyzed: ID: #{blob.id}, Analyzed?: #{blob.analyzed?}, Previewable?: #{blob.previewable?}"
      render json: { status: "ok", analyzed: blob.analyzed?, previewable: blob.previewable? }, status: :ok
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Blob not found for SGID: #{params[:sgid]}, Error: #{e.message}"
      render json: { error: "Blob not found" }, status: :not_found
    rescue StandardError => e
      Rails.logger.error "Unexpected error in analyze: #{e.class}, Message: #{e.message}, Backtrace: #{e.backtrace.first(5).join("\n")}"
      render json: { error: "Failed to analyze blob: #{e.message}" }, status: :unprocessable_entity
    end
  end


  def preview
    Rails.logger.debug "Preview endpoint called with SGID: #{params[:sgid]}"
    begin
      blob = ActiveStorage::Blob.resolve_from_sgid(params[:sgid])
      if blob.nil?
        Rails.logger.error "Blob not found for SGID: #{params[:sgid]}"
        render json: { error: "Blob not found" }, status: :not_found
        return
      end
      Rails.logger.debug "Blob found: ID: #{blob.id}, Filename: #{blob.filename}, Analyzed?: #{blob.analyzed?}, Previewable?: #{blob.previewable?}"
      if blob.previewable?
        blob.analyze
        preview = blob.preview(resize_to_limit: [800, 600])
        Rails.logger.debug "Preview generated for blob ID: #{blob.id}, URL: #{rails_representation_url(preview, only_path: false)}"
        render json: {
          preview_url: rails_representation_url(preview, only_path: false),
          url: rails_blob_url(blob, disposition: "attachment"),
          sgid: blob.signed_id,
          filename: blob.filename.to_s,
          content_type: blob.content_type
        }, status: :ok
      else
        # For videos or other files that aren't previewable (no ffmpeg / MuPDF etc.),
        # still succeed so the trix attachment can be added (JS won't treat as error).
        # The editor will show the file name; no thumbnail preview.
        Rails.logger.debug "Blob not previewable (non-fatal for attachment): #{blob.id} #{blob.filename}"
        render json: {
          preview_url: nil,
          url: rails_blob_url(blob, disposition: "attachment"),
          sgid: blob.signed_id,
          filename: blob.filename.to_s,
          content_type: blob.content_type
        }, status: :ok
      end
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Blob not found for SGID: #{params[:sgid]}, Error: #{e.message}"
      render json: { error: "Blob not found" }, status: :not_found
    rescue StandardError => e
      Rails.logger.error "Unexpected error in preview: #{e.class}, Message: #{e.message}, Backtrace: #{e.backtrace.first(5).join("\n")}"
      render json: { error: "Internal server error" }, status: :internal_server_error
    end
  end
end
