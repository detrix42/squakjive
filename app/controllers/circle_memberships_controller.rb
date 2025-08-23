
class CircleMembershipsController < ApplicationController
  def destroy
    _params = circle_membership_params

    circle = current_user.circles.find(_params[:circle_id])
    return head :not_found unless circle
    return head :forbidden unless circle.user_id == current_user.id

    # Do not allow removing the owner
    return head :unprocessable_entity if _params[:user_id].to_i == circle.user_id

    membership = circle.circle_memberships.find_by(user_id: _params[:user_id])
    mem_user = membership.user

    membership.destroy

    respond_to do |format|
      format.html { redirect_to dashboard_path }
      format.turbo_stream do
        render turbo_stream: [
               turbo_stream.remove("sidebar-user-item-#{mem_user.id}"),
               turbo_stream.update("circle-members-count-#{circle.id}",
                                   "(#{circle.members_count})")
               ]
      end
    end

  end

  def destroy_self
    circle_id = params[:circle_id] || params.dig(:circle_membership, :circle_id)
    return head :unprocessable_entity unless circle_id.present?

    circle = Circle.find_by(id: circle_id)
    return head :not_found unless circle

    membership = circle.circle_memberships.find_by(user_id: current_user.id)
    return head :not_found unless membership

    membership.destroy!

    # If the user had this circle selected, clear/update their selected circle
    if current_user.user_profile.selected_circle.to_i == circle.id
      fallback_id = current_user.selected_circle&.id || 0
      current_user.user_profile.update(selected_circle: fallback_id)
    end

    respond_to do |format|
      format.html { redirect_to dashboard_path, notice: "You left the circle." }
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove("circle-id-#{circle.id}")
      end
    end
  end


  private

  def circle_membership_params
    params.expect(circle_membership: [:circle_id, :user_id])
    # params.require(:circle_membership).permit(:circle_id, :user_id)

  end
end
