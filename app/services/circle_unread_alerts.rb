class CircleUnreadAlerts
  def self.unread_circle_ids_for(user, circles)
    circle_ids = Array(circles).map(&:id).compact.uniq
    return [] if circle_ids.empty?

    read_states = user.circle_read_states.where(circle_id: circle_ids).index_by(&:circle_id)
    latest_by_circle = Squak
      .where(circle_id: circle_ids)
      .where.not(user_id: user.id)
      .group(:circle_id)
      .maximum(:created_at)

    circle_ids.select do |circle_id|
      latest = latest_by_circle[circle_id]
      next false unless latest

      last_read = read_states[circle_id]&.last_read_at || Time.utc(1970, 1, 1)
      latest > last_read
    end
  end

  def self.mark_circle_read!(user, circle)
    return if circle.blank? || circle.id.to_i.zero?

    user.circle_read_states.find_or_initialize_by(circle: circle).update!(last_read_at: Time.current)
    broadcast_mark_read(user, circle.id)
    broadcast_unread_snapshot(user)
  end

  def self.broadcast_new_squak(squak)
    circle = squak.circle
    return if circle.blank?

    recipient_ids = circle.all_members.where.not(id: squak.user_id).pluck(:id)
    recipient_ids.each do |user_id|
      user = User.find_by(id: user_id)
      next unless user

      broadcast_mark_unread(user, circle.id)
      broadcast_unread_snapshot(user)
    end
  end

  def self.broadcast_unread_snapshot(user)
    circles = (user.circles + user.joined_circles).uniq
    CircleAlertsChannel.broadcast_to(
      user,
      {
        event: "unread_snapshot",
        unread_circle_ids: unread_circle_ids_for(user, circles)
      }
    )
  end

  def self.broadcast_mark_unread(user, circle_id)
    Turbo::StreamsChannel.broadcast_append_to(
      [user, :circle_alerts],
      target: "circle-alerts-bridge",
      partial: "circle_alerts/event",
      locals: { circle_id: circle_id, action: "mark_unread" }
    )
  end

  def self.broadcast_mark_read(user, circle_id)
    Turbo::StreamsChannel.broadcast_append_to(
      [user, :circle_alerts],
      target: "circle-alerts-bridge",
      partial: "circle_alerts/event",
      locals: { circle_id: circle_id, action: "mark_read" }
    )
  end
end