module ApplicationHelper
  SQUAKJIVE_AVATAR_SEED = "squak42"
  ROBOHASH_BASE_URL = "https://robohash.org"

  def self.robohash_avatar_url(seed, size: "60x60")
    "#{ROBOHASH_BASE_URL}/#{ERB::Util.url_encode(seed.to_s)}?size=#{size}"
  end

  def robohash_avatar_url(seed, size: "60x60")
    ApplicationHelper.robohash_avatar_url(seed, size: size)
  end

  def squakjive_avatar_url(size: "60x60")
    robohash_avatar_url(SQUAKJIVE_AVATAR_SEED, size: size)
  end
  # def render_action_text_content(rich_text)
  #   rich_text.body.to_html do |attachment|
  #     render_action_text_attachment(attachment)
  #   end
  # end
  #
  # def render_action_text_attachment(attachment)
  #   render partial: 'active_storage/blobs/blob', locals: { blob: attachment.blob }
  # end

end
