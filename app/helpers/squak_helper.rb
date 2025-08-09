module SquakHelper
  ALLOWED_TAGS  = %w[p br div span strong b em i u a ul ol li img video source].freeze
  ALLOWED_ATTRS = %w[href rel target class style src alt controls].freeze

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

end
