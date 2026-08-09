# frozen_string_literal: true

class UserSerializer
  def self.as_json(user)
    return nil if user.nil?

    {
      id: user.id,
      username: user.username,
      email: user.email,
      selected_circle_id: user.user_profile&.selected_circle.to_i
    }
  end
end
