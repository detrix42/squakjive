module SquakHelper
  ALLOWED_TAGS  = %w[p br div span strong b em i u a ul ol li img video source].freeze
  ALLOWED_ATTRS = %w[href rel target class src alt controls].freeze

  # Usage: <%= render_squak_body(squak) %>
  def render_squak_body(squak)
    return "" if squak.blank? || squak.body.blank?
    sanitize(squak.body, tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRS)
  end

  # Or, if you just have raw HTML:
  # Usage: <%= sanitize_squak_html(html_string) %>
  def sanitize_squak_html(html)
    sanitize(html.to_s, tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRS)
  end

  # Extract the first URL from the body (works on plain text or HTML)
  def first_url_from_html(html)
    fragment = Nokogiri::HTML::DocumentFragment.parse(html.to_s)

    # 1) Prefer an explicit anchor href
    if (a = fragment.at_css('a[href]'))
      href = a["href"].to_s.strip
      return href if href.match?(/\Ahttps?:\/\/\S+\z/i)
    end

    # 2) Fallback: search plain text for a URL
    text = fragment.text
    match = text.match(/\bhttps?:\/\/[^\s<>"')]+/i)
    match && match[0]

  end

  # Extract multiple URLs from HTML (anchors first, then raw text)
  def all_urls_from_html(html, max: nil)
    frag = Nokogiri::HTML::DocumentFragment.parse(html.to_s)

    # 1) anchor hrefs
    hrefs = frag.css('a[href]').map { |a| a['href'].to_s.strip }.select { |h| h =~ /\Ahttps?:\/\/\S+\z/i }

    # 2) raw text URLs fallback
    text_urls = frag.text.scan(/\bhttps?:\/\/[^\s<>"')]+/i)

    urls = (hrefs + text_urls).uniq
    max ? urls.first(max) : urls
  end


  # Get (and cache) link preview data for a URL
  # Returns a hash like { url:, title:, site_name:, image:, desc: } or nil
  def link_preview_for(url)
    return nil if url.blank?
    Rails.cache.fetch(["link_preview", url], expires_in: 12.hours) do
      LinkPreviewFetcher.call(url)
    end
  end


end
