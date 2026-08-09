# frozen_string_literal: true

class SquakSerializer
  include Rails.application.routes.url_helpers

  def self.as_json(squak, current_user: nil)
    new.as_json(squak, current_user: current_user)
  end

  def as_json(squak, current_user: nil)
    return nil if squak.nil?

    body_html = safe_body_html(squak)
    body_text = safe_body_text(squak)
    attachments = extract_attachments(squak, body_html)
    link_previews = extract_link_previews(body_html)

    can_destroy = if current_user
      squak.user_id == current_user.id || squak.circle&.user_id == current_user.id
    end

    {
      id: squak.id,
      circle_id: squak.circle_id,
      body_text: body_text,
      body_html: body_html,
      attachments: attachments,
      link_previews: link_previews,
      created_at: squak.created_at.iso8601,
      updated_at: squak.updated_at.iso8601,
      can_destroy: can_destroy,
      user: {
        id: squak.user_id,
        username: squak.user&.username
      }
    }
  end

  private

  def safe_body_html(squak)
    squak.body&.body&.to_html.to_s
  rescue StandardError
    ""
  end

  def safe_body_text(squak)
    html = safe_body_html(squak)
    if html.present?
      fragment = Nokogiri::HTML::DocumentFragment.parse(html)
      # Strip attachment/preview markup so mobile feed doesn't repeat captions
      # that are already shown as structured cards.
      fragment.css(
        ".attachment, .link-preview, figure.attachment, action-text-attachment, video, img"
      ).remove
      cleaned = fragment.text.to_s.gsub(/[ \t]+/, " ").gsub(/\n{3,}/, "\n\n").strip
      return cleaned if cleaned.present?
    end

    squak.body&.to_plain_text.to_s
  rescue StandardError
    ""
  end


  def extract_attachments(squak, body_html)
    by_signed_id = {}

    # Prefer embeds association (reliable for mobile-created posts)
    rich_text = squak.rich_text_body
    if rich_text
      rich_text.embeds.each do |attachment|
        blob = attachment.blob
        next unless blob

        by_signed_id[blob.signed_id] = BlobSerializer.as_json(blob)
      end
    end

    # Also parse data attributes from HTML for older / web posts
    if body_html.present?
      fragment = Nokogiri::HTML::DocumentFragment.parse(body_html)
      fragment.css("[data-blob-signed-id], action-text-attachment[sgid]").each do |node|
        signed_id = node["data-blob-signed-id"].presence || node["sgid"].presence
        next if signed_id.blank? || by_signed_id.key?(signed_id)

        blob = resolve_blob(signed_id)
        if blob
          by_signed_id[blob.signed_id] = BlobSerializer.as_json(blob)
        else
          # Best-effort from attributes alone
          kind = node["data-kind"].presence || guess_kind(node["data-content-type"])
          by_signed_id[signed_id] = {
            signed_id: signed_id,
            filename: node["data-filename"].presence || "file",
            content_type: node["data-content-type"],
            byte_size: node["data-byte-size"]&.to_i,
            kind: kind,
            url: node.at_css("a[href], source[src], video[src], img[src]")&.[]("href") ||
              node.at_css("source")&.[]("src") ||
              node.at_css("img")&.[]("src"),
            download_url: nil,
            preview_url: node["data-preview-url"].presence || node.at_css("img")&.[]("src")
          }.compact
        end
      end
    end

    by_signed_id.values
  end

  def extract_link_previews(body_html)
    return [] if body_html.blank?

    fragment = Nokogiri::HTML::DocumentFragment.parse(body_html)
    previews = []

    fragment.css(".link-preview[data-url], .link-preview-youtube, .link-preview-tweet").each do |node|
      url = node["data-url"].presence || node.at_css("a[href]")&.[]("href")
      next if url.blank?

      type = node["data-preview-type"].presence ||
        (node["class"].to_s.include?("youtube") ? "youtube" : nil) ||
        (node["class"].to_s.include?("tweet") ? "tweet" : "link")

      previews << {
        type: type,
        url: url,
        title: node["data-title"].presence || node.at_css(".link-preview-title, .card-title")&.text&.strip,
        thumbnail: node["data-thumbnail"].presence || node.at_css("img")&.[]("src"),
        text: node["data-desc"].presence || node.at_css(".link-preview-desc")&.text&.strip,
        site_name: node["data-site-name"].presence || node.at_css(".link-preview-site, .text-muted")&.text&.strip
      }.compact
    end

    previews.uniq { |p| p[:url] }
  end

  def resolve_blob(signed_id)
    ActiveStorage::Blob.find_signed(signed_id)
  rescue StandardError
    begin
      ActiveStorage::Blob.resolve_from_sgid(signed_id) if ActiveStorage::Blob.respond_to?(:resolve_from_sgid)
    rescue StandardError
      nil
    end
  end

  def guess_kind(content_type)
    ct = content_type.to_s
    return "image" if ct.start_with?("image/")
    return "video" if ct.start_with?("video/")
    return "pdf" if ct == "application/pdf"
    "file"
  end
end
