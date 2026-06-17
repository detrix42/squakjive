class UserProfileController < ApplicationController
  before_action :authenticate_user!

  def update_selected_circle
    circle_id = params.expect(:circle_id)&.to_i
    if circle_id == 0 || current_user.circles.exists?(id: circle_id) ||
       current_user.circle_memberships.exists?(circle_id: circle_id)
      current_user.select_circle(circle_id)
      if circle_id.positive?
        circle = current_user.circles.find_by(id: circle_id) ||
          current_user.joined_circles.find_by(id: circle_id)
        CircleUnreadAlerts.mark_circle_read!(current_user, circle) if circle
      end
      head :ok
    else
      head :bad_request
    end
  end
end
