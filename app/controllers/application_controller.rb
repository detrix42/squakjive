class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  before_action :log_params if Rails.env.development?
  before_action :configure_permitted_parameters, if: :devise_controller?

  rescue_from ActionController::InvalidAuthenticityToken do |e|
    begin
      hdr_token  = request.headers["X-CSRF-Token"]
      exp_token  = (form_authenticity_token rescue nil)
      sess_id    = request.session.id
      cookie_len = (request.headers["Cookie"] || "").bytesize

      Rails.logger.error(
        "CSRF DEBUG: InvalidAuthenticityToken " \
          "cookie_bytes=#{cookie_len} session_id=#{sess_id.inspect} " \
          "hdr_token(10)=#{hdr_token&.to_s&.slice(0,10)} " \
          "expected(10)=#{exp_token&.to_s&.slice(0,10)} " \
          "origin=#{request.headers['Origin']} referer=#{request.headers['Referer']}"
      )
    rescue => log_err
      Rails.logger.error("CSRF DEBUG logging failed: #{log_err.class}: #{log_err.message}")
    end

    raise e
  end


    protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:username, :email])
    devise_parameter_sanitizer.permit(:account_update, keys: [:username, :email])
  end
  def after_sign_in_path_for(user)
    dashboard_path
  end


  private

  def log_params

    Rails.logger.debug "application controller --> PARAMS: #{params.inspect}"

    puts "\n\n---------------------------------------------"
    puts "Controller: #{controller_name}##{action_name}"
    puts "PARAMS: #{params.inspect}"
    puts "---------------------------------------------\n\n"
  end
end
