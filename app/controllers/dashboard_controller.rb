class DashboardController < ApplicationController
  before_action :authenticate_user!
  def index
    @username = current_user.username
    @email = current_user.email

    if @selected_circle
      logger.debug "Dashboard controller index (selected circle): #{@selected_circle.name}"
    end

    @selected_circle_name = @selected_circle.name if @selected_circle

    @circles = current_user.circles + current_user.joined_circles.uniq
    selected_circle_id = current_user.user_profile&.selected_circle_id
    @selected_circle = @circles.find { |c| c.id == selected_circle_id }
    @squaks = Squak.for_circle(@selected_circle, current_user)

  end



  private

end
