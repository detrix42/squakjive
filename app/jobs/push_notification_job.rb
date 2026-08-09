# frozen_string_literal: true

class PushNotificationJob < ApplicationJob
  queue_as :default

  # data must be JSON-serializable (string keys preferred)
  def perform(user_ids, title, body, data = {})
    MobilePushNotifier.deliver_now(
      user_ids: user_ids,
      title: title,
      body: body,
      data: data
    )
  end
end
