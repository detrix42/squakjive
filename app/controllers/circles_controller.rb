class CirclesController < ApplicationController
  def index
    @circles = [AllCircle.new, *current_user.circles]
    @selected_circle = current_user.user_profile.selected_circle || AllCircle.new
    @selected_circle_name = current_user.user_profile.selected_circle.name

    # logger.debug "Circles controller index (selected circle): #{@selected_circle}"
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
    circle = current_user.circles.find(params[:circle_id])

    circle.destroy!

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove("circle-id-#{circle.id}")
      end
      format.html { redirect_to dashboard_path, notice: "Circle removed" }
    end


  end



  def add_user_modal
    @circle = Circle.find(params[:circle_id])
    @available_users = User.all.where.not(
      id: @circle.members.pluck(:id)
    ).where.not(id: current_user.id)
     .where.not(id: @circle.user_invites.pluck(:user_id))

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
                                "#{@circle.members_count}"),
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

  def invite_user
    @circle = Circle.find(params[:circle_id])
    @user = User.find(params[:user_id])

    @invite = UserInvite.new(circle: @circle, user: @user)
    if @invite.save
      respond_to do |format|
        format.turbo_stream do
          flash.now[:notice] = "Invite sent to #{@user.username}"
          streams = [
            turbo_stream.remove("modal-user-item-#{@user.id}"),
            turbo_stream.update("flash", partial: "shared/flashes")
          ]
          # the following is a hack to hide the modal if there are no more invites left
          if (@circle.members.count + @circle.user_invites.count) >= User.where.not(id: [@circle.members.select(:id), current_user.id]).count
            streams << turbo_stream.update("circle-add-user-modal", "")
          end
          render turbo_stream: streams
        end

        format.html do
          redirect_to dashboard_path, notice: "Invite sent to #{@user.username}"
        end
      end

    else
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = "Could not send invite."
          render turbo_stream: turbo_stream.update("flash", partial: "shared/flashes"), status: :unprocessable_entity
        end
        format.html { redirect_to dashboard_path, alert: "Could not send invite." }
      end

    end
  end


  private
  def circle_params
    params.expect(circle: [:name])
  end


end

