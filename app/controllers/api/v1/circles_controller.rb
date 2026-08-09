# frozen_string_literal: true

module Api
  module V1
    class CirclesController < BaseController
      # GET /api/v1/circles
      def index
        circles = (current_user.circles + current_user.joined_circles).uniq
        unread_ids = CircleUnreadAlerts.unread_circle_ids_for(current_user, circles)

        render json: {
          circles: circles.map { |c|
            CircleSerializer.as_json(c, current_user: current_user, unread: unread_ids.include?(c.id))
          }
        }
      end

      # GET /api/v1/circles/:id
      def show
        circle = accessible_circle(params[:id])
        return render json: { error: "Circle not found" }, status: :not_found unless circle

        unread = CircleUnreadAlerts.unread_circle_ids_for(current_user, [circle]).include?(circle.id)
        render json: {
          circle: CircleSerializer.as_json(
            circle,
            current_user: current_user,
            unread: unread,
            include_members: true
          ),
          pending_invites: circle.user_invites.includes(:user).map { |i| InviteSerializer.as_json(i) }
        }
      end

      # POST /api/v1/circles
      # body: { name: "..." }
      def create
        circle = current_user.circles.build(name: params[:name].to_s.strip)

        if circle.save
          current_user.select_circle(circle.id)
          render json: {
            circle: CircleSerializer.as_json(circle, current_user: current_user, unread: false)
          }, status: :created
        else
          render_validation_errors(circle)
        end
      end

      # DELETE /api/v1/circles/:id
      def destroy
        circle = current_user.circles.find_by(id: params[:id])
        return render json: { error: "Circle not found" }, status: :not_found unless circle

        circle.destroy!
        head :no_content
      end

      # DELETE /api/v1/circles/:id/leave
      def leave
        circle = current_user.joined_circles.find_by(id: params[:id])
        return render json: { error: "Not a member of this circle" }, status: :not_found unless circle

        membership = circle.circle_memberships.find_by(user_id: current_user.id)
        return render json: { error: "Not a member of this circle" }, status: :not_found unless membership

        membership.destroy!

        if current_user.user_profile.selected_circle.to_i == circle.id
          fallback = current_user.selected_circle
          current_user.user_profile.update(selected_circle: fallback&.id || 0)
        end

        head :no_content
      end

      private

      def accessible_circle(id)
        current_user.circles.find_by(id: id) ||
          current_user.joined_circles.find_by(id: id)
      end
    end
  end
end
