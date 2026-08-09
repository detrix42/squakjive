# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Auth", type: :request do
  describe "POST /api/v1/auth/register" do
    it "creates a user and returns a token" do
      post "/api/v1/auth/register",
           params: {
             username: "mobile_user",
             email: "mobile@example.com",
             password: "password123",
             password_confirmation: "password123",
             device_name: "android"
           },
           as: :json

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["token"]).to be_present
      expect(body["user"]["username"]).to eq("mobile_user")
      expect(User.find_by(username: "mobile_user")).to be_present
    end

    it "returns errors for invalid registration" do
      post "/api/v1/auth/register",
           params: { username: "", email: "bad", password: "x" },
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body["errors"]).to be_present
    end
  end

  describe "POST /api/v1/auth/login" do
    let!(:user) { create(:user, username: "alice", password: "password123") }

    it "returns a token for valid credentials" do
      post "/api/v1/auth/login",
           params: { username: "alice", password: "password123", device_name: "linux" },
           as: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["token"]).to be_present
      expect(body["user"]["id"]).to eq(user.id)
    end

    it "rejects bad passwords" do
      post "/api/v1/auth/login",
           params: { username: "alice", password: "wrong" },
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /api/v1/auth/logout" do
    let!(:user) { create(:user) }
    let!(:token) { create(:api_token, user: user) }

    it "destroys the current token" do
      delete "/api/v1/auth/logout",
             headers: { "Authorization" => "Bearer #{token.token}" }

      expect(response).to have_http_status(:no_content)
      expect(ApiToken.find_by(id: token.id)).to be_nil
    end

    it "requires auth" do
      delete "/api/v1/auth/logout"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
