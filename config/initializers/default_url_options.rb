# frozen_string_literal: true

# Ensure all URL helpers use HTTPS on the production host (blob/media URLs for mobile).
if Rails.env.production?
  Rails.application.routes.default_url_options[:host] = "squakjive.novasector.net"
  Rails.application.routes.default_url_options[:protocol] = "https"
end
