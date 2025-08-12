class SquaksController < ApplicationController
  before_action :authenticate_user!

  def index
    @circle = getCircle
    @squaks = Squak.for_circle(@circle).reorder(id: :desc).limit(20)
  end

  def create
    squak_params = params.expect(squak: [:body, :circle_id, {images: []}])
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

    per_page  = (params[:limit].presence || 20).to_i.clamp(5, 100)
    before_id = params[:before_id].presence&.to_i

    scope = Squak.for_circle(circle).reorder(id: :desc)
    scope = scope.where("id < ?", before_id) if before_id
    @page = scope.limit(per_page)

    respond_to do |format|
      format.turbo_stream do
        if before_id
          # If no more rows, return 204 so the client stops
          if @page.empty?
            head :no_content
          else
            render turbo_stream: turbo_stream.before(
              "squaks-sentinel",
              partial: "squaks/squak",
              collection: @page,
              as: :squak
            )
          end

        else
          # First load/reload
          render turbo_stream: turbo_stream.replace(
            "squak-view",
            partial: "squaks/turbo_squak_index",
            locals: { squaks: @page, circleId: @circle_id }
          )
        end
      end

      format.html do
        render partial: "squaks/squak_index", locals: { squaks: @page, circleId: @circle_id }
      end
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
