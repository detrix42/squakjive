class SquaksController < ApplicationController
  before_action :authenticate_user!

  def index
    @squaks = Squak.visible_to(current_user)
  end

  def create
    squak_params = params.expect(squak: [:body, :circle_id])
    # Rails.logger.debug "squaks_controller --> RAW PARAMS:\n #{params.inspect}\n************************"


    # Rails.logger.debug "SQUAK_PARAMS: #{squak_params.inspect}"

    @squak = current_user.squaks.create(squak_params)

    Rails.logger.debug "SQUAK ERRORS: #{@squak.errors.full_messages}" if @squak.errors.any?

    redirect_to dashboard_path
  end

  def squaks
    circle_id = params.expect(:circle_id)
    circle = current_user.circles.find_by(id: circle_id) || current_user.circle_memberships.find_by(circle_id: circle_id)&.circle
    # circle ||= current_user.circles.first
    squaks = Squak.for_circle(circle, current_user)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "squak-view",
          partial: "squaks/turbo_squak_index",
          locals: { squaks: squaks })
      end
      format.html { render partial: "squaks/squak_index", locals: { squaks: squaks } }
    end
  end




  private

  def param_circle_id
    params.expect(:circle_id)
  end

end
