# frozen_string_literal: true

module Api
  module V1
    class MembersController < BaseController
      # DELETE /api/v1/circles/:circle_id/members/:id
      # Owner removes a member (not themselves / not the owner id)
      def destroy
        circle = current_user.circles.find_by(id: params[:circle_id])
        return render json: { error: "Circle not found" }, status: :not_found unless circle
        return render json: { error: "Only the owner can remove members" }, status: :forbidden unless circle.user_id == current_user.id

        user_id = params[:id].to_i
        if user_id == circle.user_id
          return render json: { error: "Cannot remove the circle owner" }, status: :unprocessable_entity
        end

        membership = circle.circle_memberships.find_by(user_id: user_id)
        return render json: { error: "Member not found" }, status: :not_found unless membership

        membership.destroy!
        head :no_content
      end
    end
  end
end
