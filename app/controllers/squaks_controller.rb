class SquaksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_squak, only: [:show, :destroy]

  def index
    @circle = getCircle
    @squaks = Squak.for_circle(@circle).reorder(id: :desc).limit(20)
  end

  def show
    # Add circle-based authorization, e.g., if current_user.in_circle_for?(@squak)
    #   render :show
    # else
    #   redirect_to root_path, alert: "Not authorized"
    # end
    # method squaks below returns all or a turbo stream
    # turbo stream renders a single squak that prepends to the list
    # reflecting whats in the database
    # this show method will probably be deleted later.
  end

  def create
    squak_params = params.expect(squak: [ :body, :circle_id ])
    # Rails.logger.debug "squaks_controller --> RAW PARAMS:\n #{params.inspect}\n************************"
    # Rails.logger.debug "SQUAK_PARAMS: #{squak_params.inspect}"

    @squak = current_user.squaks.new(squak_params)

    Rails.logger.debug "SQUAK ERRORS: #{@squak.errors.full_messages}" if @squak.errors.any?

    # If user attached images but provided no text, set a minimal placeholder
    # if @squak.body.to_s.strip.blank? && (
    #   Array(params.dig(:squak, :images)).present? || Array(params.dig(:squak, :files))).present?
    #   @squak.body = "Image is attached"
    # end

    if @squak.save
      squak = render_to_string(partial: "squaks/squak", locals: { squak: @squak })
      # Broadcast a Turbo Stream append that uses your ERB partial
      Turbo::StreamsChannel.broadcast_prepend_to(
        "squaks",
        target: "squaks-list",
        html: squak
      )

      # Turbo Stream response for the submitter (immediate UI update)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.prepend(
              "squaks-list",
              partial: "squaks/squak",
              locals: { squak: @squak }
          ),
          # turbo_stream.update("squak-editor", ""),
          # turbo_stream.update("squak-body", "")
          ]
        end

        format.html { head :ok }
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
    # Broadcast removal so other clients update too
    Turbo::StreamsChannel.broadcast_remove_to("squaks", target: target_id)

    respond_to do |format|
      # Remove from the submitter’s DOM immediately
      format.turbo_stream { render turbo_stream: turbo_stream.remove(target_id) }

      # If the request negotiated HTML, still return a turbo-stream so the UI updates
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
