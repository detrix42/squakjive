require 'rails_helper'

RSpec.describe "UserProfiles", type: :request do
  include Devise::Test::IntegrationHelpers
  describe "GET /selected_circle" do
    it "returns http success" do
      get "/user_profile/selected_circle"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /user_profile/unread_alerts" do
    let(:user) do
      User.create!(
        username: "reader#{SecureRandom.hex(4)}",
        email: "reader#{SecureRandom.hex(4)}@example.com",
        password: "password123"
      )
    end
    let(:owner) do
      User.create!(
        username: "owner#{SecureRandom.hex(4)}",
        email: "owner#{SecureRandom.hex(4)}@example.com",
        password: "password123"
      )
    end
    let(:circle) { Circle.create!(name: "Unread Alerts", user: owner) }

    before do
      CircleMembership.create!(circle: circle, user: user)
      sign_in user
      Squak.create!(user: owner, circle: circle, body: "hello")
    end

    it "returns unread circle ids for the signed-in user" do
      get "/user_profile/unread_alerts"

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to eq("unread_circle_ids" => [circle.id])
    end
  end

  describe "POST /user_profile/mark_circle_read" do
    let(:user) do
      User.create!(
        username: "reader#{SecureRandom.hex(4)}",
        email: "reader#{SecureRandom.hex(4)}@example.com",
        password: "password123"
      )
    end
    let(:owner) do
      User.create!(
        username: "owner#{SecureRandom.hex(4)}",
        email: "owner#{SecureRandom.hex(4)}@example.com",
        password: "password123"
      )
    end
    let(:circle) { Circle.create!(name: "Mark Read", user: owner) }

    before do
      CircleMembership.create!(circle: circle, user: user)
      sign_in user
      Squak.create!(user: owner, circle: circle, body: "hello")
    end

    it "marks the circle read for the signed-in user" do
      post "/user_profile/mark_circle_read", params: { circle_id: circle.id }, as: :json

      expect(response).to have_http_status(:success)
      get "/user_profile/unread_alerts"
      expect(response.parsed_body).to eq("unread_circle_ids" => [])
    end

    it "rejects circles the user does not belong to" do
      other_circle = Circle.create!(name: "Other", user: owner)

      post "/user_profile/mark_circle_read", params: { circle_id: other_circle.id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

end
