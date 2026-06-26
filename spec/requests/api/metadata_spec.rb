require "rails_helper"

RSpec.describe "Api::V1::Metadata", type: :request do
  describe "GET /api/v1/metadata" do
    it "returns bad request for an invalid URL" do
      get "/api/v1/metadata", params: { url: "not-a-url" }

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq("error" => "Invalid URL")
    end

    it "returns not found when no preview is available" do
      allow(LinkPreviewFetcher).to receive(:call).and_return(nil)

      get "/api/v1/metadata", params: { url: "https://example.com" }

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to eq("error" => "no preview available")
    end

    it "returns link metadata with image fields for a regular site" do
      allow(LinkPreviewFetcher).to receive(:call).and_return(
        url: "https://example.com/article",
        title: "Example Article",
        site_name: "Example",
        image: "https://example.com/preview.jpg",
        desc: "A short description"
      )

      get "/api/v1/metadata", params: { url: "https://example.com/article" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        "type" => "link",
        "title" => "Example Article",
        "url" => "https://example.com/article",
        "image" => "https://example.com/preview.jpg",
        "thumbnail" => "https://example.com/preview.jpg",
        "site_name" => "Example",
        "desc" => "A short description"
      )
    end

    it "returns tweet metadata from X oEmbed" do
      allow(LinkPreviewFetcher).to receive(:call).and_return(
        url: "https://x.com/Upworkout/status/2066036369126826267",
        title: "Up Workout (@Upworkout)",
        site_name: "X",
        image: "https://pbs.twimg.com/ext_tw_video_thumb/123/pu/img/thumb.jpg",
        desc: "Most people blame their mattress.",
        preview_type: :tweet,
        media_type: :video,
        duration_ms: 25311,
        author_avatar: "https://pbs.twimg.com/profile_images/123/lDUcgkJy_normal.jpg"
      )

      get "/api/v1/metadata", params: { url: "https://x.com/Upworkout/status/2066036369126826267" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        "type" => "tweet",
        "title" => "Up Workout (@Upworkout)",
        "text" => "Most people blame their mattress.",
        "thumbnail" => "https://pbs.twimg.com/ext_tw_video_thumb/123/pu/img/thumb.jpg",
        "url" => "https://x.com/Upworkout/status/2066036369126826267",
        "media_type" => "video",
        "duration_ms" => 25311,
        "author_avatar" => "https://pbs.twimg.com/profile_images/123/lDUcgkJy_normal.jpg"
      )
    end

    it "returns youtube metadata with a thumbnail" do
      allow(LinkPreviewFetcher).to receive(:call).and_return(
        url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        title: "Never Gonna Give You Up - YouTube",
        site_name: "YouTube",
        image: "https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg",
        desc: nil
      )

      get "/api/v1/metadata", params: { url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        "type" => "youtube",
        "title" => "Never Gonna Give You Up",
        "thumbnail" => "https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg",
        "url" => "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
      )
    end
  end
end