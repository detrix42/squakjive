# frozen_string_literal: true

require "rails_helper"

RSpec.describe CircleFeedChannel, type: :channel do
  let(:owner) { create(:user) }
  let(:circle) { create(:circle, user: owner) }
  let(:token) { create(:api_token, user: owner) }

  before do
    stub_connection current_user: owner
  end

  it "subscribes when the user can access the circle" do
    subscribe(circle_id: circle.id)
    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from(CircleFeedChannel.stream_name(circle.id))
  end

  it "rejects when the circle is not accessible" do
    other = create(:circle)
    subscribe(circle_id: other.id)
    expect(subscription).to be_rejected
  end
end
