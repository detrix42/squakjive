class AttachmentsController < ApplicationController
  before_action :authenticate_user!, only: [:view]

  def view
    blob = resolve_blob_for_view(params[:signed_id])
    unless blob&.image?
      head :not_found
      return
    end

    @blob = blob
    @filename = blob.filename.to_s
    @image_url = rails_blob_url(blob, disposition: "inline")
    @download_url = rails_blob_url(blob, disposition: "attachment")

    render layout: "viewer"
  end

  def create
    @attachment = Attachment.new(attachment_params)
    if @attachment.save
      file = @attachment.file
      render json: {
        url: rails_blob_url(file, disposition: "attachment"),
        content_type: file.content_type,
        filename: file.filename.to_s,
        attachable_sgid: file.signed_id
      }, status: :ok
    else
      render json: { error: @attachment.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  end

  def preview
    logger.debug "Preview endpoint called with SGID: #{params[:sgid]}"
    begin
      blob = ActiveStorage::Blob.resolve_from_sgid(params[:sgid])
      if blob.nil?
        logger.error "Blob not found for SGID: #{params[:sgid].inspect}"
        render json: { error: "Blob not found" }, status: :not_found
        return
      end
      logger.debug "Blob found: ID: #{blob.id}, Filename: #{blob.filename}, Analyzed?: #{blob.analyzed?}, Previewable?: #{blob.previewable?}"
      if blob.previewable?
        blob.analyze
        preview = blob.preview(resize_to_limit: [800, 600]).processed
        render json: {
          preview_url: rails_blob_url(preview, disposition: "inline"),
          url: rails_blob_url(blob, disposition: "attachment"),
          attachable_sgid: blob.signed_id,
          filename: blob.filename.to_s,
          content_type: blob.content_type
        }, status: :ok
      else
        logger.error "Blob not previewable: ID: #{blob.id}, Filename: #{blob.filename}"
        render json: { error: "Cannot generate preview" }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotFound => e
      logger.error "Blob not found for SGID: #{params[:sgid].inspect}, Error: #{e.message}"
      render json: { error: "Blob not found" }, status: :not_found
    rescue ActiveStorage::PreviewError, ActiveStorage::Preview::UnprocessedError => e
      logger.error "Preview error: #{e.class}, Message: #{e.message}, Backtrace: #{e.backtrace.first(5).join("\n")}"
      render json: { error: "Failed to generate preview: #{e.message}" }, status: :unprocessable_entity
    rescue StandardError => e
      logger.error "Unexpected error in preview: #{e.class}, Message: #{e.message}, Backtrace: #{e.backtrace.first(5).join("\n")}"
      render json: { error: "Internal server error: #{e.message}" }, status: :internal_server_error
    end
  end

  def analyze
    logger.debug "Analyze endpoint called with SGID: #{params[:sgid]}"
    begin
      blob = ActiveStorage::Blob.resolve_from_sgid(params[:sgid])
      if blob.nil?
        logger.error "Blob not found for SGID: #{params[:sgid].inspect}"
        render json: { error: "Blob not found" }, status: :not_found
        return
      end
      logger.debug "Blob found: ID: #{blob.id}, Filename: #{blob.filename}, ContentType: #{blob.content_type}"
      blob.analyze
      logger.debug "Blob analyzed: ID: #{blob.id}, Analyzed?: #{blob.analyzed?}, Previewable?: #{blob.previewable?}"
      render json: { status: "ok", analyzed: blob.analyzed?, previewable: blob.previewable? }, status: :ok
    rescue ActiveRecord::RecordNotFound => e
      logger.error "Blob not found for SGID: #{params[:sgid].inspect}, Error: #{e.message}"
      render json: { error: "Blob not found" }, status: :not_found
    rescue ActiveStorage::PreviewError, ActiveStorage::Preview::UnprocessedError => e
      logger.error "Preview error in analyze: #{e.class}, Message: #{e.message}, Backtrace: #{e.backtrace.first(5).join("\n")}"
      render json: { error: "Failed to analyze blob: #{e.message}" }, status: :unprocessable_entity
    rescue StandardError => e
      logger.error "Unexpected error in analyze: #{e.class}, Message: #{e.message}, Backtrace: #{e.backtrace.first(5).join("\n")}"
      render json: { error: "Internal server error: #{e.message}" }, status: :internal_server_error
    end
  end

  private

  def resolve_blob_for_view(signed_id)
    return nil if signed_id.blank?

    ActiveStorage::Blob.resolve_from_sgid(signed_id)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def attachment_params
    params.expect(attachment: [:file])
  end
end
