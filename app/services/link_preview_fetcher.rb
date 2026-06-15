require "net/http"
require "nokogiri"
require "json"
require "cgi"
require "uri"

class LinkPreviewFetcher
  YT_OEMBED = "https://www.youtube.com/oembed?format=json&url="
  X_OEMBED = "https://publish.x.com/oembed?omit_script=1&url="

  def self.call(url)
    new(url).call
  end

  def initialize(url)
    @url = url
  end

  def call
    uri = URI.parse(@url)

    if twitter_status_url?(uri)
      if (tweet = fetch_x_oembed(@url))
        return tweet
      end
    end

    if (og = fetch_og(uri))
      return og
    end

    if youtube_host?(uri.host)
      if (embed = fetch_youtube_oembed(@url))
        return {
          url:       embed[:url] || @url,
          title:     embed[:title],
          site_name: "YouTube",
          image:     embed[:thumbnail_url],
          desc:      nil
        }
      end
    end

    nil
  rescue => e
    Rails.logger.warn("LinkPreviewFetcher error: #{e.class} #{e.message}")
    nil
  end

  private

  def fetch_x_oembed(url)
    uri = URI.parse(X_OEMBED + CGI.escape(url))
    resp = http_get(uri)
    return nil unless resp&.is_a?(Net::HTTPSuccess)

    data = JSON.parse(resp.body) rescue nil
    return nil unless data.is_a?(Hash) && data["html"].present?

    author_name = data["author_name"].to_s.strip
    author_url = data["author_url"].to_s.strip
    handle = twitter_handle_from_url(author_url)
    text = extract_tweet_text(data["html"])

    title = if author_name.present? && handle.present?
      "#{author_name} (@#{handle})"
    elsif author_name.present?
      author_name
    else
      "Post on X"
    end

    {
      url:          data["url"].presence || url,
      title:        title,
      site_name:    "X",
      image:        fetch_x_media_thumbnail(url),
      desc:         text,
      preview_type: :tweet
    }
  end

  def extract_tweet_text(html)
    doc = Nokogiri::HTML(html)
    paragraph = doc.at_css("blockquote.twitter-tweet p") || doc.at_css("blockquote p")
    return nil unless paragraph

    paragraph.css("a").each do |anchor|
      href = anchor["href"].to_s
      anchor.remove if href.match?(%r{pic\.twitter\.com|t\.co}i)
    end

    paragraph.text.gsub(/\s+/, " ").strip.presence
  end

  def fetch_x_media_thumbnail(url)
    resp = http_get(URI.parse(url))
    return nil unless resp&.is_a?(Net::HTTPSuccess)

    doc = Nokogiri::HTML(resp.body)

    doc.css('link[rel="preload"][as="image"]').each do |link|
      href = link["href"].to_s
      next if href.blank? || href.include?("profile_images")

      return href if href.include?("pbs.twimg.com")
    end

    nil
  end

  def twitter_handle_from_url(author_url)
    return nil if author_url.blank?

    path = URI.parse(author_url).path.to_s
    handle = path.split("/").reject(&:blank?).first
    handle.presence
  rescue URI::InvalidURIError
    nil
  end

  def twitter_status_url?(uri)
    host = uri.host.to_s.downcase
    return false unless host.end_with?("twitter.com", "x.com") || host == "mobile.twitter.com"

    uri.path.to_s.match?(%r{/status/\d+}i)
  end

  def fetch_og(uri)
    resp = http_get(uri)
    return nil unless resp&.is_a?(Net::HTTPSuccess)

    doc = Nokogiri::HTML(resp.body)

    og = {
      url:       meta(doc, "og:url") || @url,
      title:     meta(doc, "og:title") || doc.at_css("title")&.text&.strip,
      site_name: meta(doc, "og:site_name"),
      image:     meta(doc, "og:image"),
      desc:      meta(doc, "og:description") || meta(doc, "description")
    }

    return nil if og[:title].blank? && og[:image].blank?
    og
  end

  def fetch_youtube_oembed(url)
    uri = URI.parse(YT_OEMBED + CGI.escape(url))
    resp = http_get(uri)
    return nil unless resp&.is_a?(Net::HTTPSuccess)

    data = JSON.parse(resp.body) rescue nil
    return nil unless data

    {
      url: data["author_url"],
      title: data["title"],
      thumbnail_url: data["thumbnail_url"]
    }
  end

  def youtube_host?(host)
    return false if host.blank?
    host.downcase!
    host.end_with?("youtube.com", "youtu.be", "m.youtube.com")
  end

  def http_get(uri, redirect_limit: 5)
    raise ArgumentError, "too many HTTP redirects" if redirect_limit <= 0

    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: 5, open_timeout: 5) do |http|
      req = Net::HTTP::Get.new(uri)
      req["User-Agent"] = "SquakJiveLinkPreview/1.0"
      resp = http.request(req)

      if resp.is_a?(Net::HTTPRedirection)
        location = resp["location"].to_s
        return nil if location.blank?

        next_uri = URI.parse(location)
        next_uri = URI.join(uri, location) if next_uri.relative?
        return http_get(next_uri, redirect_limit: redirect_limit - 1)
      end

      resp
    end
  end

  def meta(doc, name)
    doc.at_xpath("//meta[@property='#{name}']/@content")&.value ||
      doc.at_xpath("//meta[@name='#{name}']/@content")&.value
  end
end