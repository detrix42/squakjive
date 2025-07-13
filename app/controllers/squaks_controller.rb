class SquaksController < ApplicationController
  before_action :authenticate_user!

  def index
  end

  def create
    squak_params = params.expect(squak: :body)
    Rails.logger.debug "squaks_controller --> RAW PARAMS:\n #{params.inspect}\n************************"


    Rails.logger.debug "SQUAK_PARAMS: #{squak_params.inspect}"

    @squak = current_user.squaks.create(squak_params)

    Rails.logger.debug "SQUAK ERRORS: #{@squak.errors.full_messages}" if @squak.errors.any?

    redirect_to dashboard_path
  end

  private

end
