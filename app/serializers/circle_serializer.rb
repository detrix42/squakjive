# frozen_string_literal: true

class CircleSerializer
  def self.as_json(circle, current_user: nil, unread: false, include_members: false)
    return nil if circle.nil?

    payload = {
      id: circle.id,
      name: circle.name,
      owner_id: circle.user_id,
      members_count: circle.members_count,
      is_owner: current_user ? circle.user_id == current_user.id : nil,
      unread: unread
    }

    if include_members
      payload[:members] = circle.all_members.map { |u|
        { id: u.id, username: u.username }
      }
    end

    payload
  end
end
