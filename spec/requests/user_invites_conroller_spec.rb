require 'rails_helper'

RSpec.describe "UserInviteConrollers", type: :request do
  describe "GET /accept" do
    it "returns http success" do
      get "/user_invite_conroller/accept"
      expect(response).to have_http_status(:success)
    end
  end

end
