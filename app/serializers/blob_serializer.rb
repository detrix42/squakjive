# frozen_string_literal: true

class BlobSerializer
  include Rails.application.routes.url_helpers

  def self.as_json(blob)
    new.as_json(blob)
  end

  def as_json(blob)
    return nil if blob.nil?

    kind = kind_for(blob)
    {
      signed_id: blob.signed_id,
      filename: blob.filename.to_s,
      content_type: blob.content_type,
      byte_size: blob.byte_size,
      kind: kind,
      url: rails_blob_path(blob, only_path: true),
      download_url: rails_blob_path(blob, disposition: "attachment", only_path: true),
      preview_url: preview_url_for(blob, kind)
    }
  end

  private

  def kind_for(blob)
    ct = blob.content_type.to_s
    return "image" if blob.image? || ct.start_with?("image/")
    return "video" if ct.start_with?("video/")
    return "pdf" if ct == "application/pdf"
    "file"
  end

  def preview_url_for(blob, kind)
    meta_preview = blob.metadata.with_indifferent_access["preview_url"].presence
    return meta_preview if meta_preview.present?

    if kind == "image"
      begin
        variant = blob.variant(resize_to_limit: [800, 600]).processed
        return rails_representation_path(variant, only_path: true)
      rescue StandardError
        return rails_blob_path(blob, only_path: true)
      end
    end

    if %w[video pdf].include?(kind) && blob.previewable?
      begin
        preview = blob.preview(resize_to_limit: [800, 600]).processed
        return rails_representation_path(preview, only_path: true)
      rescue StandardError
        # fall through
      end
    end

    nil
  end
end
