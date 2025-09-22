# config/initializers/active_storage_csrf_dev.rb
if Rails.env.development?
  Rails.application.config.to_prepare do
    ActiveStorage::DirectUploadsController.skip_forgery_protection


    ActiveStorage::DirectUploadsController.class_eval do
      prepend_before_action :log_csrf_context_for_direct_uploads

      rescue_from ActionController::InvalidAuthenticityToken do |e|
        hdr_token  = request.headers["X-CSRF-Token"]
        exp_token  = (form_authenticity_token rescue nil)
        cookie_len = (request.headers["Cookie"] || "").bytesize

        Rails.logger.error(
          "CSRF DEBUG (DirectUploads): cookie_bytes=#{cookie_len} " \
            "hdr_token(10)=#{hdr_token&.to_s&.slice(0,10)} " \
            "expected(10)=#{exp_token&.to_s&.slice(0,10)} " \
            "host=#{request.host} forwarded_host=#{request.headers['X-Forwarded-Host']} " \
            "base_url=#{request.base_url} origin=#{request.headers['Origin']} " \
            "proto=#{request.protocol} forwarded_proto=#{request.headers['X-Forwarded-Proto']}"
        )
        raise e
      end

      private

      def log_csrf_context_for_direct_uploads
        # Helpful context even when it doesn't error
        Rails.logger.info(
          "CSRF CONTEXT (DirectUploads): host=#{request.host} " \
            "forwarded_host=#{request.headers['X-Forwarded-Host']} " \
            "base_url=#{request.base_url} origin=#{request.headers['Origin']} " \
            "cookie_bytes=#{(request.headers['Cookie'] || '').bytesize}"
        )
      end
    end
  end
end# frozen_string_literal: true

