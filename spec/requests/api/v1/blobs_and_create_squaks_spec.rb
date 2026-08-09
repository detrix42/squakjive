# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1 Blobs and Squak create", type: :request do
  let!(:user) { create(:user, username: "poster") }
  let!(:circle) { create(:circle, user: user, name: "Mobile") }
  let!(:token) { create(:api_token, user: user) }
  let(:auth) { { "Authorization" => "Bearer #{token.token}" } }

  def fixture_upload(name, content_type)
    path = Rails.root.join("spec/fixtures/files/#{name}")
    FileUtils.mkdir_p(path.dirname)
    File.write(path, "fake-image-bytes-#{name}") unless path.exist?
    Rack::Test::UploadedFile.new(path, content_type)
  end

  describe "POST /api/v1/blobs" do
    it "uploads a file and returns blob metadata" do
      file = fixture_upload("sample.png", "image/png")

      post "/api/v1/blobs",
           params: { file: file },
           headers: auth

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      blob = body["blob"]
      expect(blob["signed_id"]).to be_present
      expect(blob["filename"]).to eq("sample.png")
      expect(blob["kind"]).to eq("image")
      expect(blob["url"]).to be_present
    end

    it "requires auth" do
      post "/api/v1/blobs", params: { file: fixture_upload("x.png", "image/png") }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/circles/:circle_id/squaks" do
    it "creates a text-only squak" do
      post "/api/v1/circles/#{circle.id}/squaks",
           params: { body_text: "Hello mobile world" },
           headers: auth,
           as: :json

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      squak = body["squak"]
      expect(squak["body_text"]).to include("Hello mobile world")
      expect(squak["circle_id"]).to eq(circle.id)
      expect(squak["user"]["username"]).to eq("poster")
    end

    it "creates a squak with attachment + link preview" do
      post "/api/v1/blobs",
           params: { file: fixture_upload("photo.jpg", "image/jpeg") },
           headers: auth
      signed_id = JSON.parse(response.body).dig("blob", "signed_id")

      post "/api/v1/circles/#{circle.id}/squaks",
           params: {
             body_text: "Look at this",
             attachment_signed_ids: [signed_id],
             link_previews: [
               {
                 type: "youtube",
                 url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                 title: "Demo video",
                 thumbnail: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg"
               }
             ]
           },
           headers: auth,
           as: :json

      expect(response).to have_http_status(:created)
      squak = JSON.parse(response.body)["squak"]
      expect(squak["attachments"].size).to eq(1)
      expect(squak["attachments"].first["kind"]).to eq("image")
      expect(squak["link_previews"].size).to eq(1)
      expect(squak["link_previews"].first["type"]).to eq("youtube")
      expect(squak["link_previews"].first["title"]).to eq("Demo video")
    end

    it "rejects empty posts" do
      post "/api/v1/circles/#{circle.id}/squaks",
           params: { body_text: "   " },
           headers: auth,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /api/v1/squaks/:id" do
    it "destroys own squak" do
      squak = create(:squak, user: user, circle: circle, body: "bye")

      delete "/api/v1/squaks/#{squak.id}", headers: auth
      expect(response).to have_http_status(:no_content)
      expect(Squak.find_by(id: squak.id)).to be_nil
    end
  end
end
