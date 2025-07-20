class CirclesController < ApplicationController
  def index
    @circles = current_user.circles

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

  private
  def circle_params
    params.expect(circle: [:name])
  end


end

