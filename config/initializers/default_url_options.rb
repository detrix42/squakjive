# config/initializers/default_url_options.rb
# Ensure all URL helpers use HTTPS on your production host
if Rails.env.production?
  Rails.application.routes.default_url_options[:host] = "squakjive.novasector.net"
  Rails.application.routes.default_url_options[:protocol] = "https"
end# frozen_string_literal: true

