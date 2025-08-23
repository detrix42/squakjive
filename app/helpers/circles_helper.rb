module CirclesHelper
  def owner_and_member?(user, circle)
    membership = circle.circle_memberships.find_by(user_id: user.id)
    membership.present? && current_user.id == circle.user_id && user.id != circle.user_id

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
end
