
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

  private

  def circle_membership_params
    params.expect(circle_membership: [:circle_id, :user_id])
    # params.require(:circle_membership).permit(:circle_id, :user_id)

  end
end
