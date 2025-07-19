class DashboardController < ApplicationController
  before_action :authenticate_user!
  def index
    @username = current_user.username
    @email = current_user.email
    @selected_circle = current_user.user_profile.selected_circle

  end
end
