require 'rails_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../../config/environment'
require 'rspec/rails'

RSpec.describe "Squaks", type: :request do
  include Devise::Test::IntegrationHelpers

  # describe "GET /index" do
  #   it "returns http success" do
  #     get squaks_path
  #     expect(response).to have_http_status(:success)
  #   end
  # end

  describe "POST /squaks" do
    context "when user is logged in" do

      it "creates a squak through the user and redirects to root_path" do
        user = create(:user)
        sign_in user, scope: :user
        expect {
          post squaks_path, params: { squak: { body: "test squak" } }
        }.to change { user.squaks.count }.by(1)

        expect(response).to redirect_to(dashboard_path)

        created_squak = user.squaks.last
        expect(created_squak.body).to eq("test squak")
        expect(created_squak.user_id).to eq(user.id)
      end

      # it "does not create a squak with invalid params and renders new" do
      #   expect {
      #     post squaks_path, params: { squak: { body: "" } }
      #   }.not_to change { user.squaks.count }
      #
      #   expect(response).to redirect_to(root_path)
      # end
    end

    context "when not logged in" do
      it "does not create a squak and redirects to login" do
        expect {
          post squaks_path, params: { squak: { body: "Test squak" } }
        }.not_to change(Squak, :count)

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
