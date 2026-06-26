require 'rails_helper'

RSpec.describe AttachmentsHelper, type: :helper do
  describe '#render_rich_text_with_attachments' do
    it 'preserves X tweet preview cards with thumbnails instead of normalizing them to image attachments' do
      preview_html = <<~HTML.strip
        <a href="https://x.com/TaraBull/status/2070233437638742326" target="_blank" rel="noopener noreferrer" class="link-preview-tweet">
          <div class="link-preview-tweet-card">
            <div class="link-preview-tweet-thumb">
              <img src="https://pbs.twimg.com/ext_tw_video_thumb/123/pu/img/thumb.jpg" alt="" class="link-preview-tweet-thumbnail">
            </div>
            <div class="link-preview-tweet-title">Spotted off Anna Maria Island</div>
            <div class="link-preview-tweet-hint">click to view on X</div>
          </div>
        </a>
      HTML

      rich_text = ActionText::RichText.new(
        name: 'body',
        body: <<~HTML
          <div>
            <action-text-attachment content-type="text/html" content="#{CGI.escapeHTML(preview_html)}"></action-text-attachment>
          </div>
        HTML
      )

      rendered = helper.render_rich_text_with_attachments(rich_text)

      expect(rendered).to include('link-preview-tweet')
      expect(rendered).to include('https://x.com/TaraBull/status/2070233437638742326')
      expect(rendered).to include('Spotted off Anna Maria Island')
      expect(rendered).to include('click to view on X')
      expect(rendered).not_to include('attachment-caption-link')
      expect(rendered).not_to include('click link above to download')
    end

    it 'renders link preview cards from HTML content attachments' do
      preview_html = <<~HTML.strip
        <div class="link-preview card link-preview--text-only">
          <div class="card-body py-2">
            <a href="https://example.com" target="_blank" rel="noopener noreferrer" class="card-title h6 mb-0">Example</a>
            <div class="link-preview-visit-hint">click link to visit site</div>
          </div>
        </div>
      HTML

      rich_text = ActionText::RichText.new(
        name: 'body',
        body: <<~HTML
          <div>
            <action-text-attachment content-type="text/html" content="#{CGI.escapeHTML(preview_html)}"></action-text-attachment>
            hello
          </div>
        HTML
      )

      rendered = helper.render_rich_text_with_attachments(rich_text)

      expect(rendered).to include('link-preview')
      expect(rendered).to include('Example')
      expect(rendered).not_to include('action-text-attachment')
    end

    it 'detects an already-rendered custom blob image even when alt precedes class' do
      blob = instance_double(
        ActiveStorage::Blob,
        filename: ActiveStorage::Filename.new('photo.png')
      )
      fragment = Nokogiri::HTML::DocumentFragment.parse(<<~HTML)
        <figure class="attachment attachment--preview">
          <a href="/download">
            <img alt="Preview of photo.png" class="attachment-preview-img" src="/photo.png">
          </a>
        </figure>
      HTML

      expect(helper.send(:image_blob_visible_in_fragment?, fragment, blob)).to be(true)
    end

    it 'detects an already-rendered remote image without attachment-preview-img class' do
      blob = instance_double(
        ActiveStorage::Blob,
        filename: ActiveStorage::Filename.new('photo.png')
      )
      fragment = Nokogiri::HTML::DocumentFragment.parse(<<~HTML)
        <figure class="attachment attachment--preview">
          <a href="/download">
            <img src="/photo.png" alt="photo.png">
          </a>
        </figure>
      HTML

      expect(helper.send(:image_blob_visible_in_fragment?, fragment, blob)).to be(true)
    end

    it 'builds image attachment markup with filename link and download hint' do
      html = helper.build_image_attachment_html(
        preview_src: '/preview.png',
        inline_url: '/attachments/abc123/view',
        download_url: '/download.png',
        filename: 'photo.png',
        size_text: '1.2 MB'
      )

      expect(html).to include('href="/attachments/abc123/view"')
      expect(html).to include('target="_blank"')
      expect(html).to include('photo.png (1.2 MB)')
      expect(html).to include('href="/download.png"')
      expect(html).to include('click link above to download')
      expect(html).to include('attachment-caption-link')
    end

    it 'normalizes legacy image figures that only show filesize' do
      fragment = Nokogiri::HTML::DocumentFragment.parse(<<~HTML)
        <figure class="attachment attachment--preview">
          <a href="/files/photo.png?disposition=attachment">
            <img alt="Preview of photo.png" class="attachment-preview-img" src="/files/photo.png?variant=1">
          </a>
          <figcaption class="attachment__caption">
            <span class="attachment__size">(1.2 MB)</span>
          </figcaption>
        </figure>
      HTML

      helper.send(:normalize_image_attachment_block!, fragment.at_css('figure'))

      normalized = fragment.to_html
      expect(normalized).to include('photo.png (1.2 MB)')
      expect(normalized).to include('disposition=inline')
      expect(normalized).to include('disposition=attachment')
      expect(normalized).to include('click link above to download')
      expect(normalized.scan(/<img\b/i).size).to eq(1)
    end
  end
end