# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserNotificationsChannel, type: :channel do
  let(:user) { create(:user) }

  before do
    stub_connection current_user: user
  end

  it "subscribes the user stream" do
    subscribe
    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from(
      UserNotificationsChannel.stream_name(user.id)
    )
  end
end
