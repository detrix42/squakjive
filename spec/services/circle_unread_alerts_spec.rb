require "rails_helper"

RSpec.describe CircleUnreadAlerts do
  include ActiveSupport::Testing::TimeHelpers
  def create_user(label)
    User.create!(
      username: "#{label}#{SecureRandom.hex(4)}",
      email: "#{label}#{SecureRandom.hex(4)}@example.com",
      password: "password123"
    )
  end

  let(:owner) { create_user("owner") }
  let(:member) { create_user("member") }
  let(:circle) { Circle.create!(name: "Alerts Circle", user: owner) }

  before do
    CircleMembership.create!(circle: circle, user: member)
  end

  def create_squak(author, body)
    Squak.create!(user: author, circle: circle, body: body)
  end

  describe ".unread_circle_ids_for" do
    it "returns circles with squaks from other users after last read" do
      create_squak(owner, "hello")

      expect(described_class.unread_circle_ids_for(member, [circle])).to eq([circle.id])
      expect(described_class.unread_circle_ids_for(owner, [circle])).to eq([])
    end

    it "returns empty after the circle is marked read" do
      create_squak(owner, "hello")
      described_class.mark_circle_read!(member, circle)

      expect(described_class.unread_circle_ids_for(member, [circle])).to eq([])
    end

    it "flags unread again when a newer squak arrives" do
      create_squak(owner, "first")
      described_class.mark_circle_read!(member, circle)

      travel 1.second do
        create_squak(owner, "second")
      end

      expect(described_class.unread_circle_ids_for(member, [circle])).to eq([circle.id])
    end
  end
end