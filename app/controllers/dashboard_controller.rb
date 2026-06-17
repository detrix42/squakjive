class DashboardController < ApplicationController
  before_action :authenticate_user!
  def index
    @username = current_user.username
    @email = current_user.email
    @invites = UserInvite
                 .where(user_id: current_user.id)
                 .includes(circle: :user)

    all_circles = (current_user.circles + current_user.joined_circles).uniq
    # List all circles (including joined) without name-based deduping.
    # This allows distinct "test circle" (or other same-name) entries in the sidebar
    # for different circle records, so squaks posted to a specific one show under the
    # correct selection on refresh and live updates are scoped correctly.
    @grouped_circles = all_circles
    @unread_circle_ids = CircleUnreadAlerts.unread_circle_ids_for(current_user, @grouped_circles)
    # (Previously grouped by name to avoid duplicates in the UI, preferring owned,
    # but that caused ambiguity when multiple circles shared a name like "test circle".)

    @selected_circle = current_user.selected_circle
    if @selected_circle
      @selected_circle_id = @selected_circle.id
      @squaks = Squak.for_circle(@selected_circle).reorder(id: :desc).limit(20)
      @selected_circle_name = @selected_circle.name
      CircleUnreadAlerts.mark_circle_read!(current_user, @selected_circle)
      @unread_circle_ids -= [@selected_circle.id]
      # logger.debug "Dashboard controller index (selected circle): #{@selected_circle.name}"
    else
      @selected_circle_id = 0
      @squaks = []
      @selected_circle_name = "No circle selected"
    end

  end



  private

end
