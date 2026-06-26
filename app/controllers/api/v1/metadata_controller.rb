module Api
  module V1
    class MetadataController < ApplicationController
      def show
        url = params[:url]
        return render json: { error: "Invalid URL" }, status: :bad_request unless valid_url?(url)

        data = fetch_metadata(url)

        if data.blank?
          return render json: { error: "no preview available" }, status: :not_found
        end

        render json: format_response(url, data)
      rescue => e
        Rails.logger.warn("MetadataController error: #{e.class} #{e.message}")
        render json: { error: "Failed to fetch metadata" }, status: :internal_server_error
      end

      private

      def fetch_metadata(url)
        cache_key = ["metadata", "v3", url]
        cached = Rails.cache.read(cache_key)
        cached = nil if cached.present? && stale_tweet_preview?(url, cached)

        return cached if cached.present?

        data = LinkPreviewFetcher.call(url)
        Rails.cache.write(cache_key, data, expires_in: 1.day) if data.present? && !stale_tweet_preview?(url, data)
        data
      end

      def stale_tweet_preview?(url, data)
        return false unless tweet_status_url?(url)

        data[:preview_type] != :tweet || data[:image].to_s.include?("profile_images")
      end

      def tweet_status_url?(url)
        url.to_s.match?(%r{(?:twitter\.com|x\.com)/(?:[^/]+/)?status/\d+}i)
      end

      def valid_url?(url)
        url.to_s.match?(/\Ahttps?:\/\/\S+\z/i)
      end

      def youtube_url?(url)
        url.match?(/youtube\.com|youtu\.be/i)
      end

      def format_response(requested_url, data)
        url = data[:url].presence || requested_url
        title = data[:title].presence || "Untitled"
        image = data[:image]

        if data[:preview_type] == :tweet
          {
            type: "tweet",
            title: title,
            text: data[:desc],
            thumbnail: image,
            url: url,
            media_type: data[:media_type]&.to_s,
            duration_ms: data[:duration_ms],
            author_avatar: data[:author_avatar]
          }.compact
        elsif youtube_url?(url) || data[:site_name] == "YouTube"
          {
            type: "youtube",
            title: title.gsub(/ - YouTube$/i, "").strip,
            thumbnail: image,
            url: url
          }
        else
          {
            type: "link",
            title: title,
            url: url,
            image: image,
            thumbnail: image,
            site_name: data[:site_name],
            desc: data[:desc]
          }.compact
        end
      end
    end
  end
end