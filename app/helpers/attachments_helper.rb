module AttachmentsHelper

  # Server-render ActionText::RichText content by replacing <action-text-attachment>
  # nodes with a figure that wraps the preview image in a link, using the element's
  # own attributes (href, url, filename, width, height, etc.).
  #
  # Usage: <%= render_rich_text_with_attachments(squak.body) %>
  def render_rich_text_with_attachments(rich_text)
    return "" if rich_text.blank? || !rich_text.respond_to?(:body)

    content = rich_text.body
    html = content.respond_to?(:to_html) ? content.to_html.to_s : content.to_s
    return html.html_safe if html.blank?

    fragment = Nokogiri::HTML::DocumentFragment.parse(html)

    fragment.css("action-text-attachment").each do |node|
      href      = node["href"].to_s.presence
      preview   = node["url"].to_s.presence # preview image/representation URL
      filename  = node["filename"].to_s.presence
      width     = node["width"].to_s.presence
      height    = node["height"].to_s.presence
      previewable = node["previewable"].to_s == "true"

      # If we don't have enough info, leave the node as-is
      next unless href && preview && previewable

      # Build the clickable preview using view helpers
      img = image_tag(
        preview,
        alt: (filename ? "Preview of #{filename}" : "Attachment preview"),
        width: width,
        height: height
      )

      link = link_to(href, title: (filename ? "Download #{filename}" : "Download file"), target: "_blank", rel: "noopener") do
        img
      end

      caption = if filename
                  content_tag(:figcaption, class: "attachment__caption") do
                    filename
                  end
                else
                  "".html_safe
                end

      figure_classes = ["attachment", "attachment--preview"]
      figure = content_tag(:figure, class: figure_classes.join(" ")) do
        safe_join([link, caption])
      end

      # Replace the custom element with our server-rendered figure
      node.replace(Nokogiri::HTML::DocumentFragment.parse(figure))
    end

    fragment.to_html.html_safe
  end

end
