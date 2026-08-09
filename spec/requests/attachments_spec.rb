require 'rails_helper'

RSpec.describe "Attachments", type: :request do
  describe "GET /create" do
    it "returns http success" do
      get "/attachments/create"
      expect(response).to have_http_status(:success)
    end
  end

end
