class BrandController < ApplicationController
  def icon
    size = normalized_size(params[:size])
    url = ApplicationHelper.robohash_avatar_url(ApplicationHelper::SQUAKJIVE_AVATAR_SEED, size: size)

    body = Rails.cache.fetch(["brand_icon", size], expires_in: 24.hours) do
      fetch_robohash(url)
    end

    send_data body,
              type: "image/png",
              disposition: "inline",
              cache_control: "public, max-age=86400"
  rescue StandardError => e
    Rails.logger.warn("brand#icon failed (#{size}): #{e.class} #{e.message}")
    head :bad_gateway
  end

  private

  def normalized_size(raw)
    value = raw.to_s.presence || "64x64"
    return value if value.match?(/\A\d{1,4}x\d{1,4}\z/)

    "64x64"
  end

  def fetch_robohash(url)
    uri = URI(url)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 5) do |http|
      response = http.get(uri.request_uri)
      raise "robohash status #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      response.body
    end
  end
end