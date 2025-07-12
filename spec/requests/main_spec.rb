# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Main", type: :request do
  describe "GET /" do
    it "is working" do
      get root_path
      expect(response).to have_http_status(200)
    end

  end

end
