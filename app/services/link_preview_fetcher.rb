require "net/http"
require "nokogiri"
require "json"
require "cgi"
require "uri"

class LinkPreviewFetcher
  YT_OEMBED = "https://www.youtube.com/oembed?format=json&url="
  X_OEMBED = "https://publish.x.com/oembed?omit_script=1&url="
  X_SYNDICATION = "https://cdn.syndication.twimg.com/tweet-result"

  def self.call(url)
    new(url).call
  end

  def initialize(url)
    @url = url
  end

  def call
    uri = URI.parse(@url)

    if twitter_status_url?(uri)
      tweet = fetch_x_preview(@url)
      return tweet if tweet.present?

      # Never fall back to page OG for tweet URLs — X only exposes the author avatar there.
      return nil
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

  def fetch_x_preview(url)
    fetch_x_syndication(url) ||
      fetch_x_syndication(url, read_timeout: 12, open_timeout: 6) ||
      fetch_x_oembed(url)
  end

  def fetch_x_syndication(url, read_timeout: 8, open_timeout: 4)
    tweet_id = tweet_id_from_url(url)
    return nil unless tweet_id

    token = syndication_token(tweet_id)
    uri = URI("#{X_SYNDICATION}?id=#{tweet_id}&token=#{token}&lang=en")
    resp = http_get(uri, read_timeout: read_timeout, open_timeout: open_timeout)
    return nil unless resp&.is_a?(Net::HTTPSuccess)

    data = JSON.parse(resp.body) rescue nil
    return nil unless data.is_a?(Hash) && data["text"].present?

    user = data["user"].is_a?(Hash) ? data["user"] : {}
    author_name = user["name"].to_s.strip
    handle = user["screen_name"].to_s.strip
    text = data["text"].to_s
      .gsub(%r{https?://t\.co/\S+}i, "")
      .gsub(/\s+/, " ")
      .strip

    title = if author_name.present? && handle.present?
      "#{author_name} (@#{handle})"
    elsif author_name.present?
      author_name
    else
      "Post on X"
    end

    {
      url:            url,
      title:          title,
      site_name:      "X",
      image:          syndication_thumbnail(data),
      desc:           text.presence,
      preview_type:   :tweet,
      media_type:     syndication_media_type(data),
      duration_ms:    data.dig("video", "durationMs"),
      author_avatar:  user["profile_image_url_https"].to_s.presence
    }
  rescue => e
    Rails.logger.warn("LinkPreviewFetcher X syndication error: #{e.class} #{e.message}")
    nil
  end

  def fetch_x_oembed(url)
    oembed_data = nil
    thumbnail = nil

    oembed_thread = Thread.new { oembed_data = fetch_x_oembed_payload(url) }
    thumbnail_thread = Thread.new { thumbnail = fetch_x_media_thumbnail(url) }
    oembed_thread.join
    thumbnail_thread.join

    return nil unless oembed_data.is_a?(Hash) && oembed_data["html"].present?

    build_x_preview_from_oembed(oembed_data, url, thumbnail)
  rescue => e
    Rails.logger.warn("LinkPreviewFetcher X oEmbed error: #{e.class} #{e.message}")
    nil
  end

  def fetch_x_oembed_payload(url)
    uri = URI.parse(X_OEMBED + CGI.escape(url))
    resp = http_get(uri)
    return nil unless resp&.is_a?(Net::HTTPSuccess)

    JSON.parse(resp.body) rescue nil
  end

  def build_x_preview_from_oembed(data, url, thumbnail)
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
      url:            data["url"].presence || url,
      title:          title,
      site_name:      "X",
      image:          thumbnail,
      desc:           text,
      preview_type:   :tweet,
      media_type:     infer_media_type_from_thumbnail(thumbnail)
    }
  end

  def infer_media_type_from_thumbnail(url)
    thumb = url.to_s
    return :video if thumb.include?("ext_tw_video_thumb") || thumb.include?("amplify_video_thumb")
    return :photo if thumb.include?("pbs.twimg.com/media/")

    nil
  end

  def syndication_thumbnail(data)
    poster = data.dig("video", "poster").to_s.strip
    return poster if twitter_media_url?(poster)

    photo = Array(data["photos"]).find { |entry| entry.is_a?(Hash) }
    photo_url = photo&.dig("url").to_s.strip
    return photo_url if twitter_media_url?(photo_url)

    media = Array(data["mediaDetails"]).find { |entry| entry.is_a?(Hash) }
    media_url = media&.dig("media_url_https").to_s.strip
    return media_url if twitter_media_url?(media_url)

    nil
  end

  def syndication_media_type(data)
    return :video if data["video"].is_a?(Hash)
    return :photo if Array(data["photos"]).any? || Array(data["mediaDetails"]).any?

    nil
  end

  def twitter_media_url?(url)
    url.present? && url.include?("pbs.twimg.com") && !url.include?("profile_images")
  end

  def syndication_token(tweet_id)
    ((tweet_id.to_f / 1_000_000_000_000_000) * Math::PI).to_i.to_s(36).tr("0o.", "")
  end

  def tweet_id_from_url(url)
    url.to_s[%r{/status/(\d+)}i, 1]
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
  rescue => e
    Rails.logger.warn("LinkPreviewFetcher X thumbnail error: #{e.class} #{e.message}")
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

  def http_get(uri, redirect_limit: 5, read_timeout: 5, open_timeout: 5)
    raise ArgumentError, "too many HTTP redirects" if redirect_limit <= 0

    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: read_timeout, open_timeout: open_timeout) do |http|
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