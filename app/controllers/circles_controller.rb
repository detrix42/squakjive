class CirclesController < ApplicationController
  def index
    @circles = current_user.circles

  end

  def new
  end

  def create
  end

  def edit
  end

  def update
  end

  def destroy
  end
end
