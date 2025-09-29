class SquaksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_squak, only: [ :destroy]

  def index
    @circle = getCircle
    @squaks = Squak.for_circle(@circle).reorder(id: :desc).limit(20)
  end

  def create
    squak_params = params.expect(squak: [:body, :circle_id])
    @squak = current_user.squaks.new(squak_params)

    Rails.logger.debug "SQUAK ERRORS: #{@squak.errors.full_messages}" if @squak.errors.any?

    if @squak.save
      # squak = render_to_string(partial: "squaks/squak", locals: { squak: @squak }, formats: [:html], cache: false)
      # Broadcast to other subscribed clients asynchronously (no render_to_string needed)
      Turbo::StreamsChannel.broadcast_prepend_later_to(
        "squaks",
        target: "squaks-list",
        partial: "squaks/squak",
        locals: { squak: @squak, user: current_user }
      )

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.prepend(
              "squaks-list",
              partial: "squaks/squak",
              locals: { squak: @squak, user: current_user }
            )
          ]
        end
        format.html { redirect_to dashboard_path, notice: "Squak created" }
        format.json { head :ok }
      end
    else
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
        format.html { head :unprocessable_entity }
        format.json { head :unprocessable_entity }
      end
    end
  end

  def squaks
    @circle_id = params.expect(:circle_id)&.to_i
    circle = (current_user.circles.find_by(id: @circle_id) ||
      current_user.circle_memberships.find_by(circle_id: @circle_id)&.circle)

    per_page = (params[:limit].presence || 20).to_i.clamp(5, 100)
    before_id = params[:before_id].presence&.to_i

    scope = Squak.for_circle(circle).reorder(id: :desc)
    scope = scope.where("id < ?", before_id) if before_id
    @page = scope.limit(per_page)

    respond_to do |format|
      format.turbo_stream do
        if before_id
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

  def destroy
    unless can_destroy?(@squak)
      return respond_to do |format|
        format.turbo_stream { head :forbidden }
        format.html { head :forbidden }
        format.json { head :forbidden }
      end
    end

    @squak.destroy
    target_id = "squak-#{@squak.id}"
    Turbo::StreamsChannel.broadcast_remove_to("squaks", target: target_id)

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(target_id) }
      format.html do
        response.headers["Content-Type"] = "text/vnd.turbo-stream.html"
        render turbo_stream: turbo_stream.remove(target_id)
      end
      format.json { head :ok }
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

  def set_squak
    @squak = Squak.find(params[:id])
  end

  def can_destroy?(squak)
    return false if squak.blank?
    return true if squak.user_id == current_user.id
    owner_id = squak.circle&.user_id
    owner_id.present? && owner_id == current_user.id
  end
end
