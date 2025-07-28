class DashboardController < ApplicationController
  before_action :authenticate_user!
  def index
    @username = current_user.username
    @email = current_user.email
    @selected_circle = current_user.selected_circle

    logger.debug "Dashboard controller index (selected circle): #{@selected_circle}"

    @selected_circle_name = @selected_circle.name if @selected_circle
    @squaks = Squak.for_circle(@selected_circle, current_user)

    # logger.debug "Dashboard controller index (username): #{@username}"
    # logger.debug "Dashboard controller index (email): #{@email}"
    # logger.debug "Dashboard controller index (selected circle): #{@selected_circle}"
    # logger.debug "Dashboard controller index (selected circle name): #{@selected_circle_name}"
    #
    # logger.debug "Dashboard controller SQUAKS: #{@squaks.inspect}"
  end



  private

end
