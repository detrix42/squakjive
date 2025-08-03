require 'rails_helper'

RSpec.describe "UserProfiles", type: :request do
  describe "GET /selected_circle" do
    it "returns http success" do
      get "/user_profile/selected_circle"
      expect(response).to have_http_status(:success)
    end
  end

end
