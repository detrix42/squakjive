# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1 Circles and Squaks", type: :request do
  let!(:owner) { create(:user, username: "owner") }
  let!(:member) { create(:user, username: "member") }
  let!(:circle) { create(:circle, user: owner, name: "Alpha") }
  let!(:membership) { create(:circle_membership, circle: circle, user: member) }
  let!(:token) { create(:api_token, user: member) }
  let(:auth) { { "Authorization" => "Bearer #{token.token}" } }

  describe "GET /api/v1/circles" do
    it "lists owned and joined circles" do
      get "/api/v1/circles", headers: auth

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      ids = body["circles"].map { |c| c["id"] }
      expect(ids).to include(circle.id)
      expect(body["circles"].first).to include("name", "members_count", "unread", "is_owner")
    end

    it "requires auth" do
      get "/api/v1/circles"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/me" do
    it "returns the current user" do
      get "/api/v1/me", headers: auth
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["user"]["username"]).to eq("member")
    end
  end

  describe "GET /api/v1/circles/:circle_id/squaks" do
    let!(:squak1) { create(:squak, user: owner, circle: circle, body: "Hello from owner") }
    let!(:squak2) { create(:squak, user: member, circle: circle, body: "Hello from member") }

    it "returns squaks newest first" do
      get "/api/v1/circles/#{circle.id}/squaks", headers: auth

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["circle_id"]).to eq(circle.id)
      expect(body["squaks"].size).to eq(2)
      expect(body["squaks"].first["id"]).to eq(squak2.id)
      expect(body["squaks"].first["body_text"]).to include("Hello")
      expect(body["meta"]["has_more"]).to eq(false)
    end

    it "supports before_id pagination" do
      get "/api/v1/circles/#{circle.id}/squaks",
          params: { before_id: squak2.id, limit: 20 },
          headers: auth

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      ids = body["squaks"].map { |s| s["id"] }
      expect(ids).to eq([squak1.id])
    end

    it "returns 404 for inaccessible circles" do
      other = create(:circle)
      get "/api/v1/circles/#{other.id}/squaks", headers: auth
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /api/v1/me/selected_circle" do
    it "updates selected circle" do
      patch "/api/v1/me/selected_circle",
            params: { circle_id: circle.id },
            headers: auth,
            as: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["selected_circle"]["id"]).to eq(circle.id)
      expect(member.reload.user_profile.selected_circle.to_i).to eq(circle.id)
    end
  end
end
