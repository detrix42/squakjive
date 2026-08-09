# frozen_string_literal: true

module Api
  module V1
    class SquaksController < BaseController
      # GET /api/v1/circles/:circle_id/squaks
      # query: before_id, limit (default 20, max 100)
      def index
        circle = accessible_circle(params[:circle_id])
        return render json: { error: "Circle not found" }, status: :not_found unless circle

        per_page = (params[:limit].presence || 20).to_i.clamp(5, 100)
        before_id = params[:before_id].presence&.to_i

        scope = Squak.for_circle(circle).includes(:user, :rich_text_body).reorder(id: :desc)
        scope = scope.where("squaks.id < ?", before_id) if before_id
        squaks = scope.limit(per_page)

        # Eager-load embeds blobs for serializer
        if squaks.any?
          ActiveRecord::Associations::Preloader.new(
            records: squaks.filter_map(&:rich_text_body),
            associations: { embeds_attachments: :blob }
          ).call
        end

        CircleUnreadAlerts.mark_circle_read!(current_user, circle) unless before_id

        render json: {
          circle_id: circle.id,
          squaks: squaks.map { |s| SquakSerializer.as_json(s, current_user: current_user) },
          meta: {
            limit: per_page,
            before_id: before_id,
            next_before_id: squaks.last&.id,
            has_more: squaks.size == per_page
          }
        }
      end

      # POST /api/v1/circles/:circle_id/squaks
      # body JSON:
      #   body_text: string
      #   attachment_signed_ids: [string]
      #   link_previews: [{ url, type, title, thumbnail, text, site_name }]
      def create
        circle = accessible_circle(params[:circle_id])
        return render json: { error: "Circle not found" }, status: :not_found unless circle

        squak = MobileSquakComposer.new(
          user: current_user,
          circle: circle,
          body_text: params[:body_text],
          attachment_signed_ids: params[:attachment_signed_ids],
          link_previews: params[:link_previews]
        ).call

        # Live web clients still listening on Turbo streams
        begin
          Turbo::StreamsChannel.broadcast_prepend_later_to(
            "circle-#{squak.circle_id}-squaks",
            target: "squaks-list",
            partial: "squaks/squak",
            locals: { squak: squak, user: current_user }
          )
        rescue StandardError => e
          Rails.logger.warn("[Api::V1::SquaksController] turbo broadcast skipped: #{e.message}")
        end

        # Flutter / mobile JSON ActionCable
        MobileRealtimeBroadcast.squak_created(squak)
        CircleUnreadAlerts.broadcast_new_squak(squak)

        render json: { squak: SquakSerializer.as_json(squak, current_user: current_user) },
               status: :created
      rescue MobileSquakComposer::ValidationError => e
        render json: { error: e.message, errors: [e.message] }, status: :unprocessable_entity
      rescue MobileSquakComposer::Error => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # DELETE /api/v1/squaks/:id
      def destroy
        squak = Squak.find_by(id: params[:id])
        return render json: { error: "Not found" }, status: :not_found unless squak
        return render json: { error: "Forbidden" }, status: :forbidden unless can_destroy?(squak)

        circle_id = squak.circle_id
        squak_id = squak.id
        target_id = "squak-#{squak_id}"
        squak.destroy

        begin
          Turbo::StreamsChannel.broadcast_remove_to("circle-#{circle_id}-squaks", target: target_id)
        rescue StandardError
          # non-fatal for mobile
        end

        MobileRealtimeBroadcast.squak_deleted(circle_id: circle_id, squak_id: squak_id)

        head :no_content
      end

      private

      def accessible_circle(id)
        current_user.circles.find_by(id: id) ||
          current_user.joined_circles.find_by(id: id)
      end

      def can_destroy?(squak)
        squak.user_id == current_user.id || squak.circle&.user_id == current_user.id
      end
    end
  end
end
