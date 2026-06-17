module CirclesHelper
  def owner_and_member?(viewer, user, circle)
    return false unless circle.user_id == viewer.id
    return false if user.id == circle.user_id
    circle.circle_memberships.exists?(user_id: user.id)

  end

  def circle_owner(circle)
    owner = User.find_by(id: circle.user_id)
    owner&.username || "Unknown"
  end

  def circle_owner?(circle, user)
    circle.user_id == user.id
  end

  def member_count(circle)
    circle.all_members.count
  end

  def circle_unread?(circle)
    @unread_circle_ids&.include?(circle.id)
  end
end
