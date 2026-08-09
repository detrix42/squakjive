# frozen_string_literal: true

class InviteSerializer
  def self.as_json(invite)
    return nil if invite.nil?

    circle = invite.circle
    owner = circle&.user

    {
      id: invite.id,
      created_at: invite.created_at.iso8601,
      circle: {
        id: circle&.id,
        name: circle&.name
      },
      invited_by: {
        id: owner&.id,
        username: owner&.username
      },
      user: {
        id: invite.user_id,
        username: invite.user&.username
      }
    }
  end
end
