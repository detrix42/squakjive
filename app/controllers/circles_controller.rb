class CirclesController < ApplicationController
  def index
    @circles = [AllCircle.new, *current_user.circles]
    @selected_circle_name = current_user.user_profile&.selected_circle || "All Circles"
    @selected_circle = @circles.find { |c| c.name == @selected_circle_name } || AllCircle.new
    @squaks = load_squaks_for(@selected_circle)
  end

  def new
    @circle = Circle.new
    render layout: false # This is important for the modal
  end

  def create
    @circle = current_user.circles.build(circle_params)

    if @circle.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.append("circles-list", partial: "circles/circle_item", locals: { circle: @circle }),
            turbo_stream.update("new-circle-modal", "")
          ]
        end
      end
    else
      render :new, status: :unprocessable_entity
    end

  end

  def edit
  end

  def update
  end

  def destroy
  end

  def squaks
    circle_id = params[:circle_id]
    if circle_id == "0"  # All Circles
      circle = AllCircle.new
    else
      circle = current_user.circles.find_by(id: circle_id) || current_user.circle_memberships.find_by(circle_id: circle_id)&.circle
      circle ||= AllCircle.new  # Fallback
      current_user.user_profile.update(selected_circle: circle.name) if circle && !circle.is_a?(AllCircle)
    end
    squaks = load_squaks_for(circle)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("squak-view", partial: "squaks/squak_index", locals: { squaks: squaks })
      end
      format.html { render partial: "squaks/squak_index", locals: { squaks: squaks } }
    end
  end

  def add_user_modal
    @circle = Circle.find(params[:circle_id])
    @available_users = User.all.where.not(
      id: @circle.members.pluck(:id)
    ).where.not(id: current_user.id)

    render partial: "circle_add_user_modal", layout: false
  end

  def add_user
    @circle = Circle.find(params[:circle_id])
    @user = User.find(params[:user_id])

    @membership = @circle.circle_memberships.build(user: @user)

    if @membership.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.remove("modal-user-item-#{@user.id}"),
            turbo_stream.update("circle-members-count-#{@circle.id}",
                                "(#{@circle.members_count})"),
            turbo_stream.append("circle-user-list-#{@circle.id}",
                              render_to_string(partial: "user_item",
                                               locals: { user: @user, circle: @circle }))
          ]
        end
      end
    else
      head :unprocessable_entity
    end
  end

  private
  def circle_params
    params.expect(circle: [:name])
  end

  def load_squaks_for(circle)
    if circle.is_a?(AllCircle)
      Squak.where(circle_id: (current_user.circles.pluck(:id) + current_user.circle_memberships.pluck(:circle_id)).uniq).order(created_at: :desc)
    else
      Squak.where(circle: circle).order(created_at: :desc)
    end
  end


end

