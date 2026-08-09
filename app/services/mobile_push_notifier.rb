# frozen_string_literal: true

# High-level push fan-out for mobile clients (FCM).
# Safe to call from request cycle; work is enqueued when possible.
class MobilePushNotifier
  class << self
    def squak_created(squak)
      return if squak.blank?

      circle = squak.circle
      return if circle.blank?

      # Do not push to the author — use a *second* account on the phone to test.
      recipient_ids = circle.all_members.pluck(:id) - [squak.user_id]
      if recipient_ids.empty?
        Rails.logger.info(
          "[MobilePushNotifier] squak ##{squak.id}: no other members to notify " \
          "(author user_id=#{squak.user_id} circle=#{circle.id})"
        )
        return
      end

      author = squak.user&.username.presence || "Someone"
      circle_name = circle.name.presence || "a circle"
      preview = squak_body_preview(squak)

      Rails.logger.info(
        "[MobilePushNotifier] squak ##{squak.id}: enqueue push to user_ids=#{recipient_ids.inspect}"
      )

      deliver(
        user_ids: recipient_ids,
        title: "#{author} in #{circle_name}",
        body: preview.presence || "New squak",
        data: {
          type: "squak.created",
          circle_id: circle.id,
          squak_id: squak.id
        }
      )
    end

    def invite_created(invite)
      return if invite.blank?

      circle_name = invite.circle&.name.presence || "a circle"
      deliver(
        user_ids: [invite.user_id],
        title: "Circle invite",
        body: "You were invited to #{circle_name}",
        data: {
          type: "invite.created",
          invite_id: invite.id,
          circle_id: invite.circle_id
        }
      )
    end

    def deliver(user_ids:, title:, body:, data: {})
      ids = Array(user_ids).map(&:to_i).uniq
      return if ids.empty?

      payload = data.respond_to?(:stringify_keys) ? data.stringify_keys : data
      PushNotificationJob.perform_later(ids, title, body, payload)
    rescue StandardError => e
      Rails.logger.warn("[MobilePushNotifier] enqueue failed: #{e.class} #{e.message}")
      PushNotificationJob.perform_now(ids, title, body, payload || {})
    end

    def deliver_now(user_ids:, title:, body:, data: {})
      client = FcmPushClient.instance
      unless client.enabled?
        Rails.logger.warn(
          "[MobilePushNotifier] FCM not configured — skip push. " \
          "Add config/fcm_service_account.json (see Flutter PUSH_SETUP.md)"
        )
        return
      end

      tokens = DeviceToken.for_users(user_ids).pluck(:id, :token, :user_id)
      if tokens.empty?
        Rails.logger.warn(
          "[MobilePushNotifier] no device_tokens for user_ids=#{user_ids.inspect} " \
          "(phone must login after real google-services.json is installed)"
        )
        return
      end

      Rails.logger.info(
        "[MobilePushNotifier] sending to #{tokens.size} token(s) title=#{title.inspect}"
      )

      tokens.each do |id, token, _user_id|
        begin
          client.send_to_token(
            token: token,
            title: title,
            body: body,
            data: data
          )
          DeviceToken.where(id: id).update_all(last_used_at: Time.current)
        rescue FcmPushClient::Error => e
          # Drop dead tokens so we stop spamming FCM
          if e.message.match?(/NOT_FOUND|UNREGISTERED|INVALID_ARGUMENT/i)
            DeviceToken.where(id: id).delete_all
            Rails.logger.info("[MobilePushNotifier] removed invalid token ##{id}")
          else
            Rails.logger.warn("[MobilePushNotifier] token ##{id}: #{e.message}")
          end
        end
      end
    end

    private

    def squak_body_preview(squak)
      text = begin
        if squak.respond_to?(:body) && squak.body.respond_to?(:to_plain_text)
          squak.body.to_plain_text.to_s
        else
          ""
        end
      rescue StandardError
        ""
      end
      text = text.gsub(/\s+/, " ").strip
      text.truncate(120)
    end
  end
end
