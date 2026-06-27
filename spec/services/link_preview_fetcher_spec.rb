require "rails_helper"

RSpec.describe LinkPreviewFetcher do
  def http_response(code, body, headers = {})
    response = instance_double(Net::HTTPResponse, body: body, code: code.to_s)
    allow(response).to receive(:is_a?) do |klass|
      klass == Net::HTTPSuccess && code.to_i.between?(200, 299)
    end
    headers.each { |key, value| allow(response).to receive(:[]).with(key).and_return(value) }
    response
  end

  describe ".call" do
    let(:tweet_url) { "https://x.com/Upworkout/status/2066036369126826267" }

    it "prefers the X syndication API for tweet URLs" do
      fetcher = described_class.new(tweet_url)
      syndication_body = {
        text: "Most people blame their mattress.",
        user: {
          name: "Up Workout",
          screen_name: "Upworkout",
          profile_image_url_https: "https://pbs.twimg.com/profile_images/123/lDUcgkJy_normal.jpg"
        },
        video: {
          poster: "https://pbs.twimg.com/ext_tw_video_thumb/123/pu/img/thumb.jpg",
          durationMs: 25311
        }
      }.to_json

      allow(fetcher).to receive(:http_get) do |uri|
        if uri.to_s.include?("cdn.syndication.twimg.com/tweet-result")
          http_response(200, syndication_body)
        end
      end

      result = fetcher.call

      expect(result).to include(
        preview_type: :tweet,
        site_name: "X",
        title: "Up Workout (@Upworkout)",
        desc: "Most people blame their mattress.",
        image: "https://pbs.twimg.com/ext_tw_video_thumb/123/pu/img/thumb.jpg",
        media_type: :video,
        duration_ms: 25311,
        author_avatar: "https://pbs.twimg.com/profile_images/123/lDUcgkJy_normal.jpg",
        url: tweet_url
      )
    end

    it "falls back to parallel X oEmbed and page scrape when syndication fails" do
      fetcher = described_class.new(tweet_url)
      oembed_body = {
        url: tweet_url,
        author_name: "Up Workout",
        author_url: "https://x.com/Upworkout",
        html: <<~HTML
          <blockquote class="twitter-tweet">
            <p lang="en" dir="ltr">
              Most people blame their mattress.
              <a href="https://t.co/33LcMSfMic">pic.twitter.com/33LcMSfMic</a>
            </p>
          </blockquote>
        HTML
      }.to_json

      allow(fetcher).to receive(:http_get) do |uri|
        if uri.to_s.include?("cdn.syndication.twimg.com/tweet-result")
          http_response(404, "")
        elsif uri.to_s.include?("publish.x.com/oembed")
          http_response(200, oembed_body)
        elsif uri.to_s.include?("x.com/Upworkout/status")
          http_response(
            200,
            '<link rel="preload" as="image" href="https://pbs.twimg.com/ext_tw_video_thumb/123/pu/img/thumb.jpg">'
          )
        end
      end

      result = fetcher.call

      expect(result).to include(
        preview_type: :tweet,
        site_name: "X",
        title: "Up Workout (@Upworkout)",
        desc: "Most people blame their mattress.",
        image: "https://pbs.twimg.com/ext_tw_video_thumb/123/pu/img/thumb.jpg",
        url: tweet_url
      )
    end

    it "does not fall back to page OG metadata for tweet URLs" do
      fetcher = described_class.new(tweet_url)
      og_html = <<~HTML
        <html>
          <head>
            <meta property="og:title" content="TaraBull (@TaraBull) on X" />
            <meta property="og:site_name" content="X (formerly Twitter)" />
            <meta property="og:image" content="https://pbs.twimg.com/profile_images/123/lDUcgkJy_200x200.jpg" />
          </head>
        </html>
      HTML

      allow(fetcher).to receive(:http_get) do |uri|
        if uri.to_s.include?("cdn.syndication.twimg.com/tweet-result")
          http_response(504, "")
        elsif uri.to_s.include?("publish.x.com/oembed")
          http_response(504, "")
        elsif uri.host&.include?("x.com")
          http_response(200, og_html)
        end
      end

      expect(fetcher.call).to be_nil
    end

    it "prefers YouTube oEmbed and keeps the video URL and thumbnail" do
      url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
      fetcher = described_class.new(url)
      oembed_body = {
        title: "Rick Astley - Never Gonna Give You Up (Official Video) (4K Remaster)",
        thumbnail_url: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg",
        author_url: "https://www.youtube.com/@RickAstleyYT"
      }.to_json

      allow(fetcher).to receive(:http_get) do |uri|
        if uri.to_s.include?("youtube.com/oembed")
          http_response(200, oembed_body)
        end
      end

      result = fetcher.call

      expect(result).to include(
        preview_type: :youtube,
        site_name: "YouTube",
        title: "Rick Astley - Never Gonna Give You Up (Official Video) (4K Remaster)",
        image: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg",
        url: url
      )
    end

    it "falls back to oEmbed when YouTube OG metadata has no image" do
      url = "https://youtu.be/dQw4w9WgXcQ"
      fetcher = described_class.new(url)
      og_html = <<~HTML
        <html>
          <head>
            <meta property="og:title" content="Rick Astley - Never Gonna Give You Up (Official Video) (4K Remaster)" />
            <meta property="og:site_name" content="YouTube" />
          </head>
        </html>
      HTML
      oembed_body = {
        title: "Rick Astley - Never Gonna Give You Up (Official Video) (4K Remaster)",
        thumbnail_url: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg"
      }.to_json

      allow(fetcher).to receive(:http_get) do |uri|
        if uri.to_s.include?("youtube.com/oembed")
          http_response(200, oembed_body)
        elsif uri.host&.include?("youtu.be")
          http_response(200, og_html)
        end
      end

      result = fetcher.call

      expect(result).to include(
        preview_type: :youtube,
        image: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg",
        url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
      )
    end

    it "uses a static thumbnail when both YouTube OG and oEmbed fail" do
      url = "https://www.youtube.com/shorts/dQw4w9WgXcQ"
      fetcher = described_class.new(url)

      allow(fetcher).to receive(:http_get).and_return(http_response(504, ""))

      result = fetcher.call

      expect(result).to include(
        preview_type: :youtube,
        url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        image: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg",
        title: "YouTube Video"
      )
    end

    it "falls back to OG metadata for non-tweet URLs" do
      url = "https://example.com/article"
      fetcher = described_class.new(url)
      html = <<~HTML
        <html>
          <head>
            <meta property="og:title" content="Example Article" />
            <meta property="og:image" content="https://example.com/preview.jpg" />
          </head>
        </html>
      HTML

      allow(fetcher).to receive(:http_get).and_return(http_response(200, html))

      result = fetcher.call

      expect(result).to include(
        title: "Example Article",
        image: "https://example.com/preview.jpg",
        url: url
      )
      expect(result).not_to include(preview_type: :tweet)
    end
  end
end