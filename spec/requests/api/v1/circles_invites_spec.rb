# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1 Circles Invites Membership", type: :request do
  let!(:owner) { create(:user, username: "owner_mobile") }
  let!(:invitee) { create(:user, username: "invitee_mobile") }
  let!(:outsider) { create(:user, username: "outsider_mobile") }
  let!(:owner_token) { create(:api_token, user: owner) }
  let!(:invitee_token) { create(:api_token, user: invitee) }
  let(:owner_auth) { { "Authorization" => "Bearer #{owner_token.token}" } }
  let(:invitee_auth) { { "Authorization" => "Bearer #{invitee_token.token}" } }

  describe "POST /api/v1/circles" do
    it "creates a circle and selects it" do
      post "/api/v1/circles",
           params: { name: "Road Trip" },
           headers: owner_auth,
           as: :json

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body.dig("circle", "name")).to eq("Road Trip")
      expect(body.dig("circle", "is_owner")).to eq(true)
      expect(owner.reload.user_profile.selected_circle.to_i).to eq(body.dig("circle", "id"))
    end

    it "rejects blank names" do
      post "/api/v1/circles", params: { name: "  " }, headers: owner_auth, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "invites flow" do
    let!(:circle) { create(:circle, user: owner, name: "Private") }

    it "owner invites by username, invitee lists/accepts" do
      post "/api/v1/circles/#{circle.id}/invites",
           params: { username: "invitee_mobile" },
           headers: owner_auth,
           as: :json

      expect(response).to have_http_status(:created)
      invite_id = JSON.parse(response.body).dig("invite", "id")

      get "/api/v1/invites", headers: invitee_auth
      expect(response).to have_http_status(:ok)
      invites = JSON.parse(response.body)["invites"]
      expect(invites.map { |i| i["id"] }).to include(invite_id)

      post "/api/v1/invites/#{invite_id}/accept", headers: invitee_auth
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("circle", "id")).to eq(circle.id)
      expect(circle.circle_memberships.exists?(user_id: invitee.id)).to be(true)
      expect(UserInvite.find_by(id: invite_id)).to be_nil
    end

    it "invitee can decline" do
      invite = create(:user_invite, circle: circle, user: invitee)

      delete "/api/v1/invites/#{invite.id}", headers: invitee_auth
      expect(response).to have_http_status(:no_content)
      expect(UserInvite.find_by(id: invite.id)).to be_nil
    end

    it "non-owner cannot invite" do
      create(:circle_membership, circle: circle, user: invitee)

      post "/api/v1/circles/#{circle.id}/invites",
           params: { username: "outsider_mobile" },
           headers: invitee_auth,
           as: :json

      expect(response).to have_http_status(:not_found).or have_http_status(:forbidden)
    end
  end

  describe "membership" do
    let!(:circle) { create(:circle, user: owner, name: "Crew") }
    let!(:membership) { create(:circle_membership, circle: circle, user: invitee) }

    it "owner removes a member" do
      delete "/api/v1/circles/#{circle.id}/members/#{invitee.id}", headers: owner_auth
      expect(response).to have_http_status(:no_content)
      expect(circle.circle_memberships.exists?(user_id: invitee.id)).to be(false)
    end

    it "member can leave" do
      delete "/api/v1/circles/#{circle.id}/leave", headers: invitee_auth
      expect(response).to have_http_status(:no_content)
      expect(circle.circle_memberships.exists?(user_id: invitee.id)).to be(false)
    end

    it "owner can destroy circle" do
      delete "/api/v1/circles/#{circle.id}", headers: owner_auth
      expect(response).to have_http_status(:no_content)
      expect(Circle.find_by(id: circle.id)).to be_nil
    end
  end

  describe "GET /api/v1/users/search" do
    it "finds users by partial username" do
      get "/api/v1/users/search", params: { q: "invitee" }, headers: owner_auth
      expect(response).to have_http_status(:ok)
      users = JSON.parse(response.body)["users"]
      expect(users.map { |u| u["username"] }).to include("invitee_mobile")
      expect(users.map { |u| u["username"] }).not_to include("owner_mobile")
    end
  end
end
