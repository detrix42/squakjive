# frozen_string_literal: true

# Mobile / Flutter feed stream for a single circle.
# Subscribe: { channel: "CircleFeedChannel", circle_id: 123 }
# Events: squak.created, squak.deleted
class CircleFeedChannel < ApplicationCable::Channel
  def subscribed
    reject unless current_user

    circle_id = params[:circle_id].to_i
    circle = accessible_circle(circle_id)
    reject unless circle

    stream_from self.class.stream_name(circle.id)
  end

  def self.stream_name(circle_id)
    "circle:#{circle_id}:feed"
  end

  private

  def accessible_circle(id)
    return nil if id.to_i.zero?

    current_user.circles.find_by(id: id) ||
      current_user.joined_circles.find_by(id: id)
  end
end
