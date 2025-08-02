class DashboardController < ApplicationController
  before_action :authenticate_user!
  def index
    @username = current_user.username
    @email = current_user.email



    # @circles = current_user.circles + current_user.joined_circles.uniq
    # selected_circle_id = current_user.user_profile&.selected_circle
    # @selected_circle = @circles.find { |c| c.id == selected_circle_id }
    # @squaks = Squak.for_circle(@selected_circle)


    all_circles = (current_user.circles + current_user.joined_circles).uniq
    @grouped_circles = all_circles.group_by { |c| c.name.downcase }.transform_values do |group|
        # Prioritize owned circle if duplicates
        owned = group.find { |c| c.user_id == current_user.id
      }
      owned || group.first  # Fallback to first if no owned
    end.values  # Returns array of unique representatives by name

    @selected_circle_id = current_user.user_profile&.selected_circle.to_i
    @selected_circle = @grouped_circles.find { |c| c.id.to_i == @selected_circle_id }  # Nil if invalid
    @squaks = Squak.for_circle(@selected_circle)

    if @selected_circle
      logger.debug "Dashboard controller index (selected circle): #{@selected_circle.name}"
    end

    @selected_circle_name = @selected_circle.name if @selected_circle

  end



  private

end
