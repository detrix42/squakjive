# frozen_string_literal: true

module Api
  module V1
    class MeController < BaseController
      # GET /api/v1/me
      def show
        render json: {
          user: UserSerializer.as_json(current_user),
          selected_circle: CircleSerializer.as_json(current_user.selected_circle)
        }
      end

      # PATCH /api/v1/me/selected_circle
      # body: { circle_id: Integer }
      def update_selected_circle
        circle_id = params[:circle_id].to_i

        if circle_id.positive?
          circle = accessible_circle(circle_id)
          return render json: { error: "Circle not found" }, status: :not_found unless circle

          current_user.select_circle(circle.id)
          CircleUnreadAlerts.mark_circle_read!(current_user, circle)
        else
          current_user.select_circle(0)
        end

        render json: {
          user: UserSerializer.as_json(current_user),
          selected_circle: CircleSerializer.as_json(current_user.selected_circle)
        }
      end

      private

      def accessible_circle(circle_id)
        current_user.circles.find_by(id: circle_id) ||
          current_user.joined_circles.find_by(id: circle_id)
      end
    end
  end
end
