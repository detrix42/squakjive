# frozen_string_literal: true

require "net/http"
require "json"

# Firebase Cloud Messaging HTTP v1 client.
#
# Credentials (first match wins):
#   ENV["FCM_SERVICE_ACCOUNT_JSON"]  — path to service account JSON
#   Rails.root/config/fcm_service_account.json
#   Rails.application.credentials.dig(:fcm, :service_account_json) — raw JSON string
#
# Project id (optional override):
#   ENV["FCM_PROJECT_ID"] or JSON "project_id"
#
# When unconfigured, {#enabled?} is false and {#send_to_token} no-ops with a log line.
class FcmPushClient
  SCOPE = "https://www.googleapis.com/auth/firebase.messaging"

  class Error < StandardError; end

  def self.instance
    @instance ||= new
  end

  def enabled?
    credentials_io.present? && project_id.present?
  end

  # @return [Hash] parsed FCM response, or nil if disabled / skipped
  def send_to_token(token:, title:, body:, data: {})
    return nil unless enabled?
    return nil if token.blank?

    message = {
      message: {
        token: token,
        notification: {
          title: title.to_s.truncate(100),
          body: body.to_s.truncate(240)
        },
        data: stringify_data(data),
        android: {
          priority: "HIGH",
          notification: {
            channel_id: "squak_jive_default",
            sound: "default",
            click_action: "FLUTTER_NOTIFICATION_CLICK"
          }
        }
      }
    }

    post_message(message)
  rescue Error => e
    Rails.logger.warn("[FcmPushClient] send failed: #{e.message}")
    raise
  end

  private

  def post_message(payload)
    uri = URI("https://fcm.googleapis.com/v1/projects/#{project_id}/messages:send")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 10

    req = Net::HTTP::Post.new(uri)
    req["Authorization"] = "Bearer #{access_token}"
    req["Content-Type"] = "application/json; charset=UTF-8"
    req.body = JSON.generate(payload)

    res = http.request(req)
    body = res.body.to_s

    unless res.is_a?(Net::HTTPSuccess)
      raise Error, "HTTP #{res.code}: #{body.truncate(400)}"
    end

    JSON.parse(body)
  end

  def access_token
    require "googleauth"
    io = credentials_io
    raise Error, "FCM credentials missing" if io.nil?

    authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: io,
      scope: SCOPE
    )
    authorizer.fetch_access_token!["access_token"]
  ensure
    io&.rewind if io.respond_to?(:rewind)
  end

  def project_id
    @project_id ||= ENV["FCM_PROJECT_ID"].presence || credentials_hash&.dig("project_id")
  end

  def credentials_hash
    return @credentials_hash if defined?(@credentials_hash)

    @credentials_hash = begin
      io = credentials_io
      io ? JSON.parse(io.read) : nil
    rescue StandardError
      nil
    ensure
      io&.rewind if io.respond_to?(:rewind)
    end
  end

  def credentials_io
    return @credentials_io if defined?(@credentials_io)

    @credentials_io = begin
      path = ENV["FCM_SERVICE_ACCOUNT_JSON"].presence
      path ||= Rails.root.join("config/fcm_service_account.json").to_s
      if path && File.file?(path)
        File.open(path)
      else
        raw = Rails.application.credentials.dig(:fcm, :service_account_json)
        raw.present? ? StringIO.new(raw) : nil
      end
    end
  end

  def stringify_data(data)
    (data || {}).each_with_object({}) do |(k, v), h|
      h[k.to_s] = v.nil? ? "" : v.to_s
    end
  end
end
