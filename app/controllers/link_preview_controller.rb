class LinkPreviewController < ApplicationController
  before_action :authenticate_user!

  def show
    url = params.expect(:url)

    unless url.match? (/^https?:\/\/\S+\z/)
      return render json: { error: "invalid url" }, status: :unprocessable_entity
    end

    data = Rails.cache.fetch(url, expires_in: 1.day) do
      LinkPreviewFetcher.call(url)
    end

    if data.present?
      render json: data
    else
      render json: { error: "no preview available" }, status: :not_found
    end
  end
end
