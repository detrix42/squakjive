class SquaksController < ApplicationController
  before_action :authenticate_user!

  def index
    @circle = getCircle
    @squaks = Squak.for_circle(@circle)
  end

  def create
    squak_params = params.expect(squak: [:body, :circle_id])
    # Rails.logger.debug "squaks_controller --> RAW PARAMS:\n #{params.inspect}\n************************"


    # Rails.logger.debug "SQUAK_PARAMS: #{squak_params.inspect}"

    @squak = current_user.squaks.create(squak_params)

    Rails.logger.debug "SQUAK ERRORS: #{@squak.errors.full_messages}" if @squak.errors.any?

    if @squak.persisted?
      squak = render_to_string(partial: "squaks/squak", locals: { squak: @squak })
      # Broadcast a Turbo Stream append that uses your ERB partial
      Turbo::StreamsChannel.broadcast_prepend_to(
        "squaks",
        target: "squaks-list",
        html: squak
      )
      head :ok
    else
      head :unprocessable_entity
    end



    # redirect_to dashboard_path
  end

  def squaks
    @circle_id = params.expect(:circle_id)&.to_i
    circle = (current_user.circles.find_by(id: @circle_id) ||
             current_user.circle_memberships.find_by(circle_id: @circle_id)&.circle)

    squaks = Squak.for_circle(circle)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "squak-view",
          partial: "squaks/turbo_squak_index",
          locals: { squaks: squaks, circleId: @circle_id })
      end
      format.html { render partial: "squaks/squak_index", locals: { squaks: squaks } }
    end
  end

  private

  def param_circle_id
    params.expect(:circle_id)
  end

  def getCircle
    circle_id = params.expect(:circle_id)&.to_i
    (current_user.circles.find_by(id: circle_id) ||
      current_user.circle_memberships.find_by(circle_id: circle_id)&.circle)
  end

end
