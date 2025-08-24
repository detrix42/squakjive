class UserInvitesController < ApplicationController
  before_action :authenticate_user!

  def accept
    invite = UserInvite.find(params[:id])
    return head :forbidden unless invite.user_id == current_user.id

    # Add user to the circle (adjust to your membership logic)
    invite.circle.circle_memberships.find_or_create_by!(user_id: current_user.id)

    circle = invite.circle
    invite.destroy!  # triggers Turbo Stream removal

    respond_to do |format|
      format.turbo_stream do
        streams = []

        # Avoid duplicates if the circle is already present
        streams << turbo_stream.remove("circle-id-#{circle.id}")

        # Append the newly joined circle to the list
        streams << turbo_stream.append(
          "circles-list",
          partial: "circles/circle_item",
          locals: { circle: circle }
        )
        render turbo_stream: streams
      end

      format.html { redirect_to dashboard_path, notice: "Invite accepted." }
    end
  end

  def decline
    invite = UserInvite.find(params[:id])
    return head :forbidden unless invite.user_id == current_user.id

    invite.destroy!  # triggers Turbo Stream removal

    respond_to do |format|
      format.turbo_stream { head :ok }
      format.html { redirect_to dashboard_path, notice: "Invite declined." }
    end
  end
end
