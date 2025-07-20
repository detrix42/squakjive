class DashboardController < ApplicationController
  before_action :authenticate_user!
  def index
    @username = current_user.username
    @email = current_user.email
    @selected_circle = current_user.user_profile.selected_circle
    if @selected_circle.nil?
      @selected_circle = Circle.new(name: "All Circles", id: 0)
    end
    @selected_circle_name = @selected_circle.name if @selected_circle

  end
end
