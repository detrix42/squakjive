# frozen_string_literal: true

class DeviceToken < ApplicationRecord
  PLATFORMS = %w[android ios web linux].freeze

  belongs_to :user

  validates :token, presence: true, uniqueness: true
  validates :platform, presence: true, inclusion: { in: PLATFORMS }

  scope :for_users, ->(user_ids) { where(user_id: user_ids) }

  def touch_last_used!
    update_column(:last_used_at, Time.current)
  end

  # Upsert by FCM registration token (one row per physical device token).
  def self.register!(user:, token:, platform: "android", device_name: nil)
    token = token.to_s.strip
    raise ArgumentError, "token blank" if token.blank?

    platform = platform.to_s.presence || "android"
    platform = "android" unless PLATFORMS.include?(platform)

    record = find_or_initialize_by(token: token)
    record.user = user
    record.platform = platform
    record.device_name = device_name.presence || record.device_name
    record.last_used_at = Time.current
    record.save!
    record
  end
end
