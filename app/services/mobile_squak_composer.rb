# frozen_string_literal: true

# Builds a Squak from mobile structured payload (no Trix):
#   body_text + attachment signed_ids + link_preview objects
#
# Persists ActionText HTML so the existing web UI still renders posts.
class MobileSquakComposer
  include ActionView::Helpers::NumberHelper
  include Rails.application.routes.url_helpers

  MAX_ATTACHMENTS = 10
  MAX_BODY_LENGTH = 10_000

  class Error < StandardError; end
  class ValidationError < Error; end

  def initialize(user:, circle:, body_text: nil, attachment_signed_ids: [], link_previews: [])
    @user = user
    @circle = circle
    @body_text = body_text.to_s
    @attachment_signed_ids = Array(attachment_signed_ids).map(&:to_s).reject(&:blank?).uniq
    @link_previews = Array(link_previews).filter_map { |p| normalize_preview(p) }
  end

  def call
    validate!

    blobs = resolve_blobs
    html = build_html(blobs)

    squak = @user.squaks.new(circle: @circle)
    squak.body = html.presence || " "

    unless squak.save
      raise ValidationError, squak.errors.full_messages.to_sentence
    end

    attach_embeds!(squak, blobs)
    CircleUnreadAlerts.broadcast_new_squak(squak)
    squak.reload
  end

  private

  def validate!
    if @attachment_signed_ids.size > MAX_ATTACHMENTS
      raise ValidationError, "Too many attachments (max #{MAX_ATTACHMENTS})"
    end

    if @body_text.length > MAX_BODY_LENGTH
      raise ValidationError, "Body is too long (max #{MAX_BODY_LENGTH} characters)"
    end

    has_text = @body_text.strip.present?
    has_attachments = @attachment_signed_ids.any?
    has_previews = @link_previews.any?

    return if has_text || has_attachments || has_previews

    raise ValidationError, "Add text, an attachment, or a link preview"
  end

  def resolve_blobs
    @attachment_signed_ids.map do |signed_id|
      blob = ActiveStorage::Blob.find_signed(signed_id)
      raise ValidationError, "Attachment not found (#{signed_id[0, 12]}…)" unless blob

      blob.analyze unless blob.analyzed?
      blob
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
      raise ValidationError, "Invalid attachment signed_id"
    end
  end

  def build_html(blobs)
    parts = []

    blobs.each do |blob|
      parts << attachment_html_for(blob)
    end

    @link_previews.each do |preview|
      parts << link_preview_html(preview)
    end

    if @body_text.strip.present?
      escaped = ERB::Util.html_escape(@body_text)
      paragraphs = escaped.split(/\r?\n\r?\n+/).map do |para|
        "<p>#{para.gsub(/\r?\n/, '<br>')}</p>"
      end
      parts.concat(paragraphs)
    end

    parts.join("\n")
  end

  def attachment_html_for(blob)
    if blob.image?
      image_attachment_html(blob)
    elsif blob.content_type.to_s.start_with?("video/")
      video_attachment_html(blob)
    elsif blob.content_type.to_s == "application/pdf"
      pdf_attachment_html(blob)
    else
      file_attachment_html(blob)
    end
  end

  def image_attachment_html(blob)
    url = rails_blob_path(blob, only_path: true)
    preview = preview_path_for(blob) || url
    size = number_to_human_size(blob.byte_size)
    filename = ERB::Util.html_escape(blob.filename.to_s)

    <<~HTML.strip
      <figure class="attachment attachment--preview attachment--image"
              data-blob-signed-id="#{blob.signed_id}"
              data-content-type="#{ERB::Util.html_escape(blob.content_type.to_s)}"
              data-filename="#{filename}"
              data-byte-size="#{blob.byte_size}"
              data-kind="image">
        <img src="#{preview}" alt="#{filename}" class="attachment-preview-img">
        <figcaption>
          <a href="#{url}" class="attachment-caption-link" data-download="true">#{filename} (#{size})</a>
        </figcaption>
      </figure>
    HTML
  end

  def video_attachment_html(blob)
    url = rails_blob_path(blob, only_path: true)
    poster = preview_path_for(blob)
    size = number_to_human_size(blob.byte_size)
    filename = ERB::Util.html_escape(blob.filename.to_s)
    poster_attr = poster.present? ? %( poster="#{poster}") : ""

    <<~HTML.strip
      <div class="attachment attachment-video"
           data-blob-signed-id="#{blob.signed_id}"
           data-content-type="#{ERB::Util.html_escape(blob.content_type.to_s)}"
           data-filename="#{filename}"
           data-byte-size="#{blob.byte_size}"
           data-kind="video"
           data-preview-url="#{poster}">
        <video controls preload="metadata"#{poster_attr} class="attachment-video-player">
          <source src="#{url}">
        </video>
        <a href="#{url}" class="attachment-caption-link" data-download="true">🎥 #{filename} (#{size})</a>
      </div>
    HTML
  end

  def pdf_attachment_html(blob)
    url = rails_blob_path(blob, only_path: true)
    preview = preview_path_for(blob)
    size = number_to_human_size(blob.byte_size)
    filename = ERB::Util.html_escape(blob.filename.to_s)
    img = if preview.present?
      %(<img src="#{preview}" alt="#{filename}" class="attachment-preview-img">)
    else
      ""
    end

    <<~HTML.strip
      <div class="attachment attachment-pdf"
           data-blob-signed-id="#{blob.signed_id}"
           data-content-type="application/pdf"
           data-filename="#{filename}"
           data-byte-size="#{blob.byte_size}"
           data-kind="pdf"
           data-preview-url="#{preview}">
        #{img}
        <a href="#{url}" class="attachment-caption-link" data-download="true">📄 #{filename} (#{size})</a>
      </div>
    HTML
  end

  def file_attachment_html(blob)
    url = rails_blob_path(blob, only_path: true)
    size = number_to_human_size(blob.byte_size)
    filename = ERB::Util.html_escape(blob.filename.to_s)
    content_type = ERB::Util.html_escape(blob.content_type.to_s)

    <<~HTML.strip
      <div class="attachment attachment-file"
           data-blob-signed-id="#{blob.signed_id}"
           data-content-type="#{content_type}"
           data-filename="#{filename}"
           data-byte-size="#{blob.byte_size}"
           data-kind="file">
        <a href="#{url}" class="attachment-caption-link" data-download="true">📎 #{filename} (#{size})</a>
      </div>
    HTML
  end

  def link_preview_html(preview)
    type = ERB::Util.html_escape(preview[:type].to_s)
    url = ERB::Util.html_escape(preview[:url].to_s)
    title = ERB::Util.html_escape(preview[:title].to_s.presence || preview[:url].to_s)
    thumb = ERB::Util.html_escape(preview[:thumbnail].to_s)
    desc = ERB::Util.html_escape(preview[:text].presence || preview[:desc].to_s)
    site = ERB::Util.html_escape(preview[:site_name].to_s)

    thumb_html = if thumb.present?
      %(<img src="#{thumb}" alt="" class="link-preview-thumb" loading="lazy">)
    else
      ""
    end

    <<~HTML.strip
      <div class="link-preview link-preview--#{type}"
           data-preview-type="#{type}"
           data-url="#{url}"
           data-title="#{title}"
           data-thumbnail="#{thumb}"
           data-desc="#{desc}"
           data-site-name="#{site}">
        <a href="#{url}" target="_blank" rel="noopener noreferrer" class="link-preview-card">
          #{thumb_html}
          <div class="link-preview-body">
            <div class="link-preview-title">#{title}</div>
            #{"<div class=\"link-preview-site\">#{site}</div>" if site.present?}
            #{"<div class=\"link-preview-desc\">#{desc}</div>" if desc.present?}
          </div>
        </a>
      </div>
    HTML
  end

  def preview_path_for(blob)
    return nil unless blob

    if blob.image?
      begin
        variant = blob.variant(resize_to_limit: [800, 600]).processed
        return rails_representation_path(variant, only_path: true)
      rescue StandardError => e
        Rails.logger.warn("MobileSquakComposer image preview failed: #{e.message}")
        return rails_blob_path(blob, only_path: true)
      end
    end

    if blob.previewable?
      begin
        preview = blob.preview(resize_to_limit: [800, 600]).processed
        return rails_representation_path(preview, only_path: true)
      rescue StandardError => e
        Rails.logger.warn("MobileSquakComposer preview failed: #{e.message}")
      end
    end

    blob.metadata.with_indifferent_access["preview_url"].presence
  end

  def attach_embeds!(squak, blobs)
    rich_text = squak.rich_text_body
    return unless rich_text

    blobs.each do |blob|
      ActiveStorage::Attachment.find_or_create_by!(
        name: "embeds",
        record_type: "ActionText::RichText",
        record_id: rich_text.id,
        blob_id: blob.id
      )
    end
    rich_text.embeds.reload
  end

  def normalize_preview(raw)
    data = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw
    data = data.to_h if data.respond_to?(:to_h)
    data = data.with_indifferent_access

    url = data[:url].to_s.strip
    return nil if url.blank?
    return nil unless url.match?(/\Ahttps?:\/\//i)

    {
      type: (data[:type].presence || "link").to_s,
      url: url,
      title: data[:title].to_s.presence,
      thumbnail: (data[:thumbnail].presence || data[:image]).to_s.presence,
      text: data[:text].to_s.presence,
      desc: data[:desc].to_s.presence,
      site_name: data[:site_name].to_s.presence
    }
  end

  # Required by url helpers when generating representation paths in some Rails versions.
  def default_url_options
    Rails.application.routes.default_url_options.presence || { host: "localhost", port: 4200 }
  end
end
