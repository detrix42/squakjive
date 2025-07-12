class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  before_action :log_params if Rails.env.development?


  private

  def log_params

    Rails.logger.debug "PARAMS: #{params.inspect}"

    puts "\n\n---------------------------------------------"
    puts "Controller: #{controller_name}##{action_name}"
    puts "PARAMS: #{params.inspect}"
    puts "---------------------------------------------\n\n"
  end
end
