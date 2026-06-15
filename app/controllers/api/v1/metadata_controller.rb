module Api
  module V1
    class MetadataController < ApplicationController
      def show
        url = params[:url]
        return render json: { error: "Invalid URL" }, status: :bad_request unless valid_url?(url)

        data = Rails.cache.fetch(["metadata", url], expires_in: 1.day) do
          LinkPreviewFetcher.call(url)
        end

        if data.blank?
          return render json: { error: "no preview available" }, status: :not_found
        end

        render json: format_response(url, data)
      rescue => e
        Rails.logger.warn("MetadataController error: #{e.class} #{e.message}")
        render json: { error: "Failed to fetch metadata" }, status: :internal_server_error
      end

      private

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

        if youtube_url?(url) || data[:site_name] == "YouTube"
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