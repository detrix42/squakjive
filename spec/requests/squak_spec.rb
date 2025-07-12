require 'rails_helper'

RSpec.describe "Squaks", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/squak/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /new" do
    it "returns http success" do
      get "/squak/new"
      expect(response).to have_http_status(:success)
    end
  end

end
