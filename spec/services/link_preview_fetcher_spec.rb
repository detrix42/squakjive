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