module Api
  module V1

    class MetadataController < ApplicationController
      def show
        url = params[:url]
        return render json: { error: "Invalid URL" }, status: :bad_request unless valid_url?(url)

        response = HTTParty.get(url, follow_redirects: true)
        doc = Nokogiri::HTML(response.body)
        title = doc.at_css("title").text.strip || "Untitled"

        if youtube_url?(url)
          video_id = extract_youtube_id(url)
          thumbnail = "https://img.youtube.com/vi/#{video_id}/0.jpg"
          title = title.gsub(/ - YouTube$/, "").strip # Clean up title
          render json: { type: "youtube", title: title, thumbnail: thumbnail, url: url }
        else
          render json: { type: "link", title: title, url: url }
        end
      rescue => e
        render json: { error: "Failed to fetch metadata" }, status: :internal_server_error
      end

      private

      def valid_url?(url)
        url.match?(/\Ahttps?:\/\//)
      end

      def youtube_url?(url)
        url.match?(/youtube\.com|youtu\.be/)
      end

      def extract_youtube_id(url)
        if url =~ /youtube\.com\/watch\?v=([^&]+)/
          $1
        elsif url =~ /youtu\.be\/([^?]+)/
          $1
        else
          ''
        end
      end
    end
  end
end
