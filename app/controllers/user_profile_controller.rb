class UserProfileController < ApplicationController
  before_action :authenticate_user!

  def update_selected_circle
    circle_id = params.expect(:circle_id)&.to_i
    if circle_id == 0 || current_user.circles.exists?(id: circle_id) ||
       current_user.circle_memberships.exists?(circle_id: circle_id)
      current_user.select_circle(circle_id)
      head :ok
    else
      head :bad_request
    end
  end
end
