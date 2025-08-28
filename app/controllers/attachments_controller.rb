class AttachmentsController < ApplicationController
  respond_to :json

  def create
    @attachment = Attachment.new(attachment_params)
    if @attachment.save
      file = @attachment.file
      render json: {
        url: rails_blob_url(file, disposition: "attachment"),
        content_type: file.content_type,
        filename: file.filename.to_s,
        sgid: file.attachable_sgid # For embeddable Global ID if needed
      }, status: :ok
    else
      render json: @attachment.errors, status: :unprocessable_entity
    end
  end

  private

  def attachment_params
    params.expect(attachment: [ :file ])
  end
end
