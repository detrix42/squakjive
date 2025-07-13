# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Main", type: :request do
  describe "GET /" do
    context "when not logged in" do
      it "is working" do
        get root_path
        expect(response).to have_http_status(200)
      end
    end

    context "when logged in" do
      it "redirects to dashboard_path" do
        user = create(:user)
        sign_in user
        get root_path
        expect(response).to redirect_to(dashboard_path)
      end

    end


  end

end
