# frozen_string_literal: true

namespace :push do
  desc "Diagnose FCM + device_tokens (push readiness)"
  task status: :environment do
    puts "=== Squak Jive push status ==="
    puts "FCM enabled: #{FcmPushClient.instance.enabled?}"
    puts "ENV FCM_PROJECT_ID: #{ENV['FCM_PROJECT_ID'].inspect}"
    puts "ENV FCM_SERVICE_ACCOUNT_JSON: #{ENV['FCM_SERVICE_ACCOUNT_JSON'].inspect}"
    path = Rails.root.join("config/fcm_service_account.json")
    puts "config/fcm_service_account.json: #{File.file?(path) ? 'present' : 'MISSING'}"
    puts "DeviceToken count: #{DeviceToken.count}"
    DeviceToken.includes(:user).find_each do |t|
      puts "  ##{t.id} user=#{t.user&.username}(#{t.user_id}) " \
           "platform=#{t.platform} last=#{t.last_used_at} " \
           "token=#{t.token.to_s[0, 24]}…"
    end
    puts "Users: #{User.order(:id).pluck(:id, :username).map { |i, u| "#{i}:#{u}" }.join(', ')}"
    puts
    puts "Test: bin/rails 'push:test[username]'"
  end

  desc "Send a test push to all device tokens for a username"
  task :test, [:username] => :environment do |_t, args|
    username = args[:username]
    abort "Usage: bin/rails 'push:test[username]'" if username.blank?

    user = User.find_by("lower(username) = ?", username.downcase)
    abort "No user #{username.inspect}" unless user

    count = user.device_tokens.count
    abort "User #{username} has 0 device_tokens (login on phone after FCM is configured)" if count.zero?

    unless FcmPushClient.instance.enabled?
      abort "FCM not configured — place service account at config/fcm_service_account.json"
    end

    puts "Sending test push to #{count} token(s) for #{username}…"
    MobilePushNotifier.deliver_now(
      user_ids: [user.id],
      title: "Squak Jive test",
      body: "If you see this, push is working (#{Time.current})",
      data: { type: "test" }
    )
    puts "Done. Check the phone."
  end
end
