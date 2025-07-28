class UserProfileController < ApplicationController
  before_action :authenticate_user!

  def update_selected_circle
    circle_id = params.expect(:circle_id)
    if circle_id.present?
      current_user.select_circle(circle_id)
      head :ok
    else
      head :bad_request
    end
  end
end
