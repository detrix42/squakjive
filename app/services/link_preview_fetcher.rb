require "net/http"
require "nokogiri"
require "json"
require "cgi"
require "uri"

class LinkPreviewFetcher
  YT_OEMBED = "https://www.youtube.com/oembed?format=json&url="

  def self.call(url)
    new(url).call
  end

  def initialize(url)
    @url = url
  end

  def call
    uri = URI.parse(@url)

    # Try normal fetch/OG first
    if (og = fetch_og(uri))
      return og
    end

    # Fallback to oEmbed for YouTube domains (incl. Shorts)
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

  def http_get(uri)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: 5, open_timeout: 5) do |http|
      req = Net::HTTP::Get.new(uri)
      req["User-Agent"] = "SquakJiveLinkPreview/1.0"
      http.request(req)
    end
  end

  def meta(doc, name)
    doc.at_xpath("//meta[@property='#{name}']/@content")&.value ||
      doc.at_xpath("//meta[@name='#{name}']/@content")&.value
  end
end
