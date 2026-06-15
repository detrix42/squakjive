module AttachmentsHelper
  include ActionText::ContentHelper

  # Low-level builder for the clean (no inline styles) preview + filename link block.
  # Prefers classes + CSS (see squak_editor/sm.scss) over style="".
  # Used by attachment_figure_html and by the render-time normalizer.
  #
  # For videos: outputs a playable <video> with poster (thumbnail) instead of static img.
  # The download link below remains for saving the original.
  def build_attachment_figure_html(preview_src:, download_url:, filename:, size_text: nil, is_video: false, video_url: nil)
    icon = is_video ? '🎥 ' : '📄 '
    attachment_class = is_video ? 'attachment-video' : 'attachment-pdf'
    size_part = size_text.present? ? " (#{size_text})" : ''

    if is_video && (video_url || download_url).present?
      vsrc = video_url || download_url
      poster_attr = preview_src.present? ? " poster=\"#{preview_src}\"" : ''
      <<~HTML.strip
        <div class="attachment #{attachment_class}">
          <video controls preload="metadata"#{poster_attr} class="attachment-video-player">
            <source src="#{vsrc}">
          </video>
          <br>
          <span class="download-hint">click link below to download</span>
          <a href="#{download_url}" target="_blank" rel="noopener" class="attachment-caption-link">
            #{icon}#{filename}#{size_part}
          </a>
        </div>
      HTML
    elsif preview_src.present? && download_url.present?
      <<~HTML.strip
        <div class="attachment #{attachment_class}">
          <a href="#{download_url}" target="_blank" rel="noopener">
            <img src="#{preview_src}" alt="#{icon}#{filename}" class="attachment-preview-img">
          </a>
          <br>
          <span class="download-hint">click link below to download</span>
          <a href="#{download_url}" target="_blank" rel="noopener" class="attachment-caption-link">
            #{icon}#{filename}#{size_part}
          </a>
        </div>
      HTML
    else
      # Fallback: at least the filename link (no preview img). Keeps the squak from looking empty.
      dl = download_url.presence || '#'
      <<~HTML.strip
        <div class="attachment #{attachment_class}">
          <a href="#{dl}" target="_blank" rel="noopener" class="attachment-caption-link">
            #{icon}#{filename}#{size_part}
          </a>
        </div>
      HTML
    end
  end

  # Build the canonical preview + filename link block for a PDF or video blob (from DB).
  # Delegates to the clean builder above. No inline styles.
  # Used at create time (inlining into rich text) and for sgid-based replacements.
  def attachment_figure_html(blob, preview_url: nil)
    return "" unless blob
    return "" unless blob.content_type.start_with?('application/pdf') || blob.content_type.start_with?('video/')

    is_video = blob.content_type.start_with?('video/')
    download_url = rails_blob_url(blob, disposition: "attachment")
    video_url = is_video ? rails_blob_url(blob, disposition: "inline") : nil
    size_text = number_to_human_size(blob.byte_size)

    effective_preview = preview_url.presence || blob.metadata.with_indifferent_access['preview_url'].presence

    if effective_preview.blank? && blob.previewable?
      begin
        preview = blob.preview(resize_to_limit: [800, 600]).processed
        effective_preview = rails_representation_url(preview)
      rescue => e
        Rails.logger.warn("attachment_figure_html: could not generate preview for #{blob.id}: #{e.message}")
      end
    end

    build_attachment_figure_html(
      preview_src: effective_preview,
      download_url: download_url,
      filename: blob.filename.to_s,
      size_text: size_text,
      is_video: is_video,
      video_url: video_url
    )
  end

  # Server-render (and upgrade) ActionText::RichText content for squak display.
  # Goals:
  # - Always show filename (not just size) in a visible link below the preview image.
  # - Normalize to clean classed HTML with **no inline style="" attributes** (user preference).
  # - Handle both previously baked <div class="attachment ..."> and partial-rendered <figure class="attachment ...">.
  # - For raw tags, use sgid + blob for accurate data.
  #
  # This fixes "empty squaks" where the attachment block was present but caption text
  # was only the size (or structure made it invisible), and revives posts by ensuring
  # the link text + preview are output.
  #
  # Usage: <%= render_rich_text_with_attachments(squak.body) %>
  def render_rich_text_with_attachments(rich_text)
    return "" if rich_text.blank? || !rich_text.respond_to?(:body)

    content = rich_text.body
    html = if content.respond_to?(:render_attachments)
             render_action_text_content(content).to_s
           elsif content.respond_to?(:to_html)
             content.to_html.to_s
           else
             content.to_s
           end
    return html.html_safe if html.blank?

    rendered_html = html
    fragment = Nokogiri::HTML::DocumentFragment.parse(rendered_html)

    # Clean up any "missing attachable" fallback messages from ActionText resolver failures.
    # Our recovery below will (re)inject the proper preview+link for video/PDF.
    fragment.css('h4').each do |h4|
      if h4.text.downcase.include?('missing') || h4.text.downcase.include?('attachment')
        h4.remove
      end
    end

    # Clean up any leftover mangled text from old inlining / sanitize passes.
    # The user is seeing things like '<' + '🎥' + 'filename (size)' + 'div>' (or '📄' for pdf)
    # even on *new* test squaks.
    #
    # Important: the stray '<' is frequently in its *own tiny text node* by itself,
    # and the trailing 'div>' (or '</div>') is in *its own tiny text node*.
    # The real caption ("🎥 filename (size)") lives in a separate middle node.
    # Therefore:
    #   1. Completely remove any text node whose *entire* stripped content is just a
    #      stray tag fragment ("<", "div>", "</div>", "<div", etc.).
    #   2. On the node(s) that carry the actual useful caption data (emoji + (size)),
    #      just strip leading/trailing whitespace (the '\n ' prefix and '\n' suffix the
    #      user is now seeing once the stray '<'/'div>' nodes are gone).
    #
    # We deliberately never delete the caption-bearing node — the user needs the
    # filename + filesize data. We no longer need to hunt for '<'/'div>' inside the
    # caption text itself, because those live in their own removed nodes.
    fragment.traverse do |node|
      next unless node.text?
      text = node.content.to_s
      stripped = text.strip

      next if stripped.empty?

      # 1. The node is *entirely* a stray opening or closing tag fragment.
      #    These are the isolated '<' and 'div>' nodes.
      if stripped == '<' || stripped == '>' ||
         stripped.downcase == 'div' || stripped.downcase == 'div>' ||
         stripped.downcase == '</div' || stripped.downcase == '</div>' ||
         stripped.downcase == '<div' || stripped == '<div>'
        node.remove
        next
      end

      # 2. The node contains the real payload (the glyph + filename + (size)).
      #    Simply strip all leading/trailing whitespace (covers '\n ', '\n', spaces, etc.).
      if (text.include?('🎥') || text.include?('📄')) && text =~ /\([^)]+\)/
        cleaned = text.strip
        if cleaned != text
          node.content = cleaned
        end
      end
    end

    # 1) Normalize/upgrade any attachment blocks (div or figure) that came from
    #    baked inlines or from the actiontext partials. This ensures filename is
    #    always in the "link text below the image" and removes any leftover inline styles.
    # Only target PDF/video (and similar file) attachments; do not re-wrap plain image
    # attachments (which use the custom_blob image case for inline preview).
    fragment.css("div.attachment, figure.attachment").each do |node|
      cls = node['class'].to_s
      next unless cls.match?(/attachment-video|attachment-pdf|attachment--video|attachment--pdf|attachment--file/)

      normalize_attachment_block!(node)
    end

    # 2) Ensure preview links always open externally in a new tab.
    fragment.css("a.link-preview-youtube, a.link-preview-tweet, .link-preview a.card-title, .link-preview-tweet-author").each do |anchor|
      href = anchor["href"].to_s.strip
      next if href.blank? || href == "#"

      anchor["target"] = "_blank"
      anchor["rel"] = "noopener noreferrer"
    end

    # 3) Unwrap HTML embeds (e.g. link preview cards from Trix content attachments).
    #    Browsers do not render custom <action-text-attachment> tags; expose the inner figure/card.
    fragment.css("action-text-attachment[content-type='text/html']").each do |node|
      inner = node.inner_html.to_s.strip
      replacement = inner.presence || node['content'].to_s
      if replacement.present?
        decoded = CGI.unescapeHTML(replacement)
        node.replace(Nokogiri::HTML::DocumentFragment.parse(decoded))
      end
    end

    # 4) Replace any remaining raw <action-text-attachment sgid=...> for PDF/video.
    #    (If the to_html still left tags, or for other rich text render paths.)
    fragment.css("action-text-attachment").each do |node|
      sgid = node['sgid'].to_s.presence
      next unless sgid

      begin
        blob = ActiveStorage::Blob.resolve_from_sgid(sgid)
        next unless blob && (blob.content_type.start_with?('application/pdf') || blob.content_type.start_with?('video/'))

        figure = attachment_figure_html(blob)
        node.replace(Nokogiri::HTML::DocumentFragment.parse(figure.to_s)) if figure.present?
      rescue ActiveRecord::RecordNotFound
        Rails.logger.debug "render_rich_text_with_attachments: blob not found for sgid #{sgid}"
      rescue => e
        Rails.logger.warn "render_rich_text_with_attachments: failed to upgrade attachment #{sgid}: #{e.message}"
      end
    end

    # 5) Strong recovery for "blank/empty" squaks (the two in family circle).
    #    Some older posts have the <action-text-attachment sgid=...> still in the *raw source*
    #    of the rich text (even if the rendered HTML became the "missing attachment" h4 or nothing,
    #    because the embeds link or resolver didn't produce a visible figure at the time).
    #    We scan the raw source for sgids, lookup the blobs (no need for the embeds association),
    #    and inject the clean preview+filename-link figure if the current rendered output
    #    doesn't already visibly contain attachment content for them.
    #    This uses the stored preview_url metadata (from the original JS upload) or server
    #    generates one now that ffmpeg is available.
    raw_source = nil
    begin
      # The rendered_html came from to_html (resolved). The raw source with tags is usually
      # still stored in the rich text's body column.
      if rich_text.respond_to?(:body)
        # Sometimes .body on the content proxy gives the source HTML
        candidate = rich_text.body.to_s
        raw_source = candidate if candidate.include?('action-text-attachment') || candidate.include?('sgid=')
      end
      if (raw_source.blank? || !raw_source.include?('sgid=')) && rich_text.respond_to?(:record)
        # Fallback via the owning record's rich_text_body association (common in this app)
        owner = rich_text.record
        if owner && owner.respond_to?(:rich_text_body)
          rt_body = owner.rich_text_body
          candidate = rt_body&.body.to_s if rt_body
          raw_source = candidate if candidate && (candidate.include?('sgid=') || candidate.include?('action-text-attachment'))
        end
      end
    rescue => e
      Rails.logger.debug "render_rich_text_with_attachments: raw source recovery error: #{e.message}"
    end

    current_output = fragment.to_html
    has_visible_attachment = current_output.match?(/class=["'][^"']*attachment-(video|pdf)|attachment-preview-img|attachment-caption-link/)

    if raw_source.present? && raw_source.include?('sgid=')
      sgids = raw_source.scan(/sgid="([^"]+)"/).flatten.uniq

      sgids.each do |sgid|
        begin
          blob = ActiveStorage::Blob.resolve_from_sgid(sgid)
          next unless blob

          if blob.content_type.start_with?('application/pdf') || blob.content_type.start_with?('video/')
            # Inject only if we don't already have visible attachment markup (prevents dups on good posts;
            # for the blank ones this will fire and add the preview + "filename (size)" link).
            if !has_visible_attachment || !current_output.include?(blob.filename.to_s)
              figure = attachment_figure_html(blob)
              if figure.present?
                node = Nokogiri::HTML::DocumentFragment.parse(figure.to_s)
                if fragment.children.any?
                  fragment.children.first.add_previous_sibling(node)
                else
                  fragment.add_child(node)
                end
                has_visible_attachment = true
              end
            end
          elsif blob.image?
            # For images, ensure a visible preview img if the standard rendering left the tag or no visible.
            if !has_visible_attachment || !current_output.match?(/attachment-preview-img.*#{Regexp.escape(blob.filename)}/)
              url = rails_blob_url(blob, disposition: "inline")
              href = rails_blob_url(blob, disposition: "attachment")
              img = image_tag(url, class: "attachment-preview-img", alt: "Preview of #{blob.filename}")
              figure = content_tag(:a, img, href: href, title: "Download #{blob.filename}")
              if figure.present?
                node = Nokogiri::HTML::DocumentFragment.parse(figure.to_s)
                if fragment.children.any?
                  fragment.children.first.add_previous_sibling(node)
                else
                  fragment.add_child(node)
                end
                has_visible_attachment = true
              end
            end
          end
        rescue ActiveRecord::RecordNotFound
          Rails.logger.debug "render_rich_text_with_attachments recovery: no blob for sgid #{sgid}"
        rescue => e
          Rails.logger.warn "render_rich_text_with_attachments recovery failed for #{sgid}: #{e.message}"
        end
      end
    end

    # Extra recovery directly from the embeds association on the rich text (if links exist
    # but the rendered markup was stripped to "missing" or blank for other reasons).
    # Complements the sgid source scan.
    if !has_visible_attachment && rich_text.respond_to?(:embeds) && rich_text.embeds.any?
      rich_text.embeds.each do |ea|
        begin
          blob = ea.blob
          next unless blob
          if blob.content_type.start_with?('application/pdf') || blob.content_type.start_with?('video/')
            if !current_output.include?(blob.filename.to_s)
              figure = attachment_figure_html(blob)
              if figure.present?
                node = Nokogiri::HTML::DocumentFragment.parse(figure.to_s)
                if fragment.children.any?
                  fragment.children.first.add_previous_sibling(node)
                else
                  fragment.add_child(node)
                end
                has_visible_attachment = true
              end
            end
          elsif blob.image?
            if !current_output.match?(/attachment-preview-img.*#{Regexp.escape(blob.filename)}/)
              url = rails_blob_url(blob, disposition: "inline")
              href = rails_blob_url(blob, disposition: "attachment")
              img = image_tag(url, class: "attachment-preview-img", alt: "Preview of #{blob.filename}")
              figure = content_tag(:a, img, href: href, title: "Download #{blob.filename}")
              if figure.present?
                node = Nokogiri::HTML::DocumentFragment.parse(figure.to_s)
                if fragment.children.any?
                  fragment.children.first.add_previous_sibling(node)
                else
                  fragment.add_child(node)
                end
                has_visible_attachment = true
              end
            end
          end
        rescue => e
          Rails.logger.debug "embeds recovery skip: #{e.message}"
        end
      end
    end

    fragment.to_html.html_safe
  end

  private

  # Extract what we can from a resolved attachment node (div or figure from partial or old bake),
  # strip inline styles, and replace the whole node with a clean classed version
  # that guarantees the filename appears in the link below the preview.
  def normalize_attachment_block!(node)
    img = node.at_css('img')
    preview_src = img ? img['src'].to_s.presence : nil

    # Clean img: remove inline styles/attrs that cause "bigger" issues or violate no-inline-style preference
    if img
      img.remove_attribute('style')
      img.remove_attribute('width')
      img.remove_attribute('height')
      classes = (img['class'].to_s.split + ['attachment-preview-img']).uniq
      img['class'] = classes.join(' ')
    end

    # Try to get a download URL (the outer or first link around the preview)
    download_link = node.at_css('a[href]')
    download_url = download_link ? download_link['href'].to_s.presence : nil

    # Recover filename. Prefer alt on the img (our generator puts "🎥 name" or "📄 name" there).
    # Fallback to existing caption/figcaption text (strip icon + size parens).
    alt = img ? img['alt'].to_s : ''
    filename = alt.sub(/^(🎥 |📄 )/, '').strip
    if filename.blank?
      cap_text = ''
      if (cap = node.at_css('figcaption'))
        cap_text = cap.text.to_s
      elsif (cap = node.at_css('.attachment-caption-link, a'))
        cap_text = cap.text.to_s
      end
      filename = cap_text.sub(/^(🎥 |📄 )/, '').strip.sub(/\s*\(.*?\)\s*$/, '').presence || 'file'
    end

    # Detect video vs pdf from classes, alt, or filename extension
    is_video = node['class'].to_s.match?(/video/i) ||
               alt.match?(/video/i) ||
               filename.match?(/\.(mp4|webm|mov|avi|mpg|m4v)$/i)

    # Try to preserve size if it was in the old text
    size_text = nil
    size_match = node.text.match(/\(([0-9.]+\s*[KMG]B)\)/i)
    size_text = size_match[1] if size_match

    # Build and replace with the clean (class-based, no style="") structure.
    # This is what makes the two "empty" squaks show their video previews + filename links.
    clean = build_attachment_figure_html(
      preview_src: preview_src,
      download_url: download_url,
      filename: filename,
      size_text: size_text,
      is_video: is_video,
      video_url: is_video ? download_url : nil
    )

    if clean.present?
      node.replace(Nokogiri::HTML::DocumentFragment.parse(clean))
    end
  end

end
