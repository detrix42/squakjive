require 'rails_helper'

RSpec.describe "Dashboards", type: :request do
  describe "GET /dashboard" do
    context "when not logged in" do
      it "reponds with a redirect to login" do
        get dashboard_path
        expect(response).to have_http_status(:redirect)
      end
    end

    context "when logged in" do
      it "successful login will redirect to dashboard" do
        user = create(:user)
        sign_in user
        get dashboard_path
        expect(response).to have_http_status(:success)
      end
    end

  end

end
