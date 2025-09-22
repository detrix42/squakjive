# config/initializers/active_storage_csrf_dev.rb
if Rails.env.development?
  Rails.application.config.to_prepare do
    ActiveStorage::DirectUploadsController.skip_forgery_protection
  end
end# frozen_string_literal: true

