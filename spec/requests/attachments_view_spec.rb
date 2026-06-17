require 'rails_helper'

RSpec.describe "Attachment image viewer", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:png_bytes) do
    File.binread(Rails.root.join('spec/fixtures/files/test_image.png'))
  rescue Errno::ENOENT
    [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
      0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
      0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
    ].pack('C*')
  end

  let(:user) do
    User.create!(
      username: "vieweruser#{SecureRandom.hex(4)}",
      email: "viewer#{SecureRandom.hex(4)}@example.com",
      password: 'password123'
    )
  end
  let!(:blob) do
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(png_bytes),
      filename: 'viewer-test.png',
      content_type: 'image/png'
    )
  end

  describe "GET /attachments/:signed_id/view" do
    it "redirects guests to sign in" do
      get attachment_view_path(blob.signed_id)
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(new_user_session_path)
    end

    it "renders the zoomable viewer for signed-in users" do
      sign_in user, scope: :user

      get attachment_view_path(blob.signed_id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-controller="image-viewer"')
      expect(response.body).to include('viewer-test.png')
      expect(response.body).to include('Scroll to zoom')
      expect(response.body).to include('disposition=inline')
    end

    it "returns not found for non-image blobs" do
      sign_in user, scope: :user
      text_blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new('hello'),
        filename: 'notes.txt',
        content_type: 'text/plain'
      )

      get attachment_view_path(text_blob.signed_id)

      expect(response).to have_http_status(:not_found)
    end
  end
end