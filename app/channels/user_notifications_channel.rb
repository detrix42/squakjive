# frozen_string_literal: true

# Per-user JSON notifications for mobile clients.
# Subscribe: { channel: "UserNotificationsChannel" }
# Events: invite.created, invite.removed, circle.unread, circle.read
class UserNotificationsChannel < ApplicationCable::Channel
  def subscribed
    reject unless current_user

    stream_from self.class.stream_name(current_user.id)
  end

  def self.stream_name(user_id)
    "user:#{user_id}:notifications"
  end
end
