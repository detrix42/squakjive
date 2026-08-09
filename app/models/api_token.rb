# frozen_string_literal: true

class ApiToken < ApplicationRecord
  belongs_to :user

  # Generates a unique, URL-safe token on create.
  has_secure_token :token

  validates :token, uniqueness: true

  scope :active, -> { all }

  def touch_last_used!
    update_column(:last_used_at, Time.current)
  end

  def self.authenticate(raw_token)
    return nil if raw_token.blank?

    token = find_by(token: raw_token)
    return nil unless token

    token.touch_last_used!
    token
  end
end
