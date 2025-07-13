class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  before_action :log_params if Rails.env.development?
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:username])
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
