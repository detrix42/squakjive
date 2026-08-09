# frozen_string_literal: true

module Api
  module V1
    class InvitesController < BaseController
      # GET /api/v1/invites
      # Pending invites for the current user
      def index
        invites = UserInvite
          .where(user_id: current_user.id)
          .includes(circle: :user, user: [])
          .order(created_at: :desc)

        render json: {
          invites: invites.map { |i| InviteSerializer.as_json(i) }
        }
      end

      # POST /api/v1/circles/:circle_id/invites
      # body: { username: "..." } or { user_id: 123 }
      def create
        circle = current_user.circles.find_by(id: params[:circle_id])
        return render json: { error: "Circle not found" }, status: :not_found unless circle
        return render json: { error: "Only the owner can invite" }, status: :forbidden unless circle.user_id == current_user.id

        invitee = find_invitee
        return render json: { error: "User not found" }, status: :not_found unless invitee
        return render json: { error: "Cannot invite yourself" }, status: :unprocessable_entity if invitee.id == current_user.id

        if circle.all_members.exists?(id: invitee.id)
          return render json: { error: "User is already a member" }, status: :unprocessable_entity
        end

        if circle.user_invites.exists?(user_id: invitee.id)
          return render json: { error: "Invite already pending" }, status: :unprocessable_entity
        end

        invite = circle.user_invites.build(user: invitee)
        if invite.save
          render json: { invite: InviteSerializer.as_json(invite) }, status: :created
        else
          render_validation_errors(invite)
        end
      end

      # POST /api/v1/invites/:id/accept
      def accept
        invite = UserInvite.find_by(id: params[:id])
        return render json: { error: "Invite not found" }, status: :not_found unless invite
        return render json: { error: "Forbidden" }, status: :forbidden unless invite.user_id == current_user.id

        circle = invite.circle
        circle.circle_memberships.find_or_create_by!(user_id: current_user.id)
        invite.destroy!

        current_user.select_circle(circle.id)

        render json: {
          circle: CircleSerializer.as_json(circle, current_user: current_user, unread: false)
        }
      end

      # DELETE /api/v1/invites/:id
      def destroy
        invite = UserInvite.find_by(id: params[:id])
        return render json: { error: "Invite not found" }, status: :not_found unless invite

        # Invitee can decline; circle owner can cancel
        allowed = invite.user_id == current_user.id || invite.circle.user_id == current_user.id
        return render json: { error: "Forbidden" }, status: :forbidden unless allowed

        invite.destroy!
        head :no_content
      end

      private

      def find_invitee
        if params[:user_id].present?
          User.find_by(id: params[:user_id])
        elsif params[:username].present?
          User.where("LOWER(username) = ?", params[:username].to_s.downcase).first
        end
      end
    end
  end
end
