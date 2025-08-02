class SquaksController < ApplicationController
  before_action :authenticate_user!

  def index
    # cid = current circle ID
    # cid = currrent_user.user_profile.selected_circle
    # @circle = Circle.find_by(id: cid)
    @circle = getCircle
    # @squaks = Squak.visible_to(current_user)
    @squaks = Squak.for_circle(circle)
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
    circle_id = params.expect(:circle_id)&.to_i
    circle = (current_user.circles.find_by(id: circle_id) ||
             current_user.circle_memberships.find_by(circle_id: circle_id)&.circle)

    squaks = Squak.for_circle(circle)
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

  # def for_circle
  #   circle_id = params[:circle_id]&.to_i
  #   circle = circle_id == 0 ? nil : current_user.circles.find_by(id: circle_id) ||
  #     current_user.circle_memberships.find_by(circle_id: circle_id)&.circle
  #   squaks = Squak.for_circle(circle)
  #   respond_to do |format|
  #     format.turbo_stream do
  #       render turbo_stream: turbo_stream.replace("squak-view",
  #                                                 partial: "squaks/squak_index",
  #                                                 locals: { squaks: squaks })
  #     end
  #     format.html { render partial: "squaks/squak_index", locals: { squaks: squaks } }
  #   end
  # end


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
