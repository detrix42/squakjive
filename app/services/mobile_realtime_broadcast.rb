# frozen_string_literal: true

# JSON ActionCable broadcasts for the Flutter client.
# Safe to call from API and web controllers; failures are logged, never raised.
class MobileRealtimeBroadcast
  class << self
    def squak_created(squak)
      return if squak.blank?

      broadcast_circle(
        squak.circle_id,
        {
          event: "squak.created",
          squak: SquakSerializer.as_json(squak)
        }
      )
      # Background push for members who are not currently on cable
      MobilePushNotifier.squak_created(squak)
    end

    def squak_deleted(circle_id:, squak_id:)
      return if circle_id.blank? || squak_id.blank?

      broadcast_circle(
        circle_id,
        {
          event: "squak.deleted",
          circle_id: circle_id.to_i,
          squak_id: squak_id.to_i
        }
      )
    end

    def invite_created(invite)
      return if invite.blank?

      broadcast_user(
        invite.user_id,
        {
          event: "invite.created",
          invite: InviteSerializer.as_json(invite)
        }
      )
      MobilePushNotifier.invite_created(invite)
    end

    def invite_removed(user_id:, invite_id:)
      return if user_id.blank? || invite_id.blank?

      broadcast_user(
        user_id,
        {
          event: "invite.removed",
          invite_id: invite_id.to_i
        }
      )
    end

    def circle_unread(user_id:, circle_id:)
      broadcast_user(
        user_id,
        {
          event: "circle.unread",
          circle_id: circle_id.to_i,
          unread: true
        }
      )
    end

    def circle_read(user_id:, circle_id:)
      broadcast_user(
        user_id,
        {
          event: "circle.read",
          circle_id: circle_id.to_i,
          unread: false
        }
      )
    end

    private

    def broadcast_circle(circle_id, payload)
      ActionCable.server.broadcast(CircleFeedChannel.stream_name(circle_id), payload)
    rescue StandardError => e
      Rails.logger.warn("[MobileRealtimeBroadcast] circle #{circle_id}: #{e.class} #{e.message}")
    end

    def broadcast_user(user_id, payload)
      ActionCable.server.broadcast(UserNotificationsChannel.stream_name(user_id), payload)
    rescue StandardError => e
      Rails.logger.warn("[MobileRealtimeBroadcast] user #{user_id}: #{e.class} #{e.message}")
    end
  end
end
