class Squak < ApplicationRecord
  belongs_to :user
  belongs_to :circle, optional: true
  # has_many_attached :images
  # has_many_attached :files

  has_rich_text :body

  # before_validation :strip_inline_images_from_body

  validates :body, presence: true, length: { maximum: 10_000 }, allow_blank: true
  validate :ensure_content, if: :body

  scope :for_circle, ->(circle) do
    if circle.nil? || (circle.respond_to?(:id) && circle.id == 0)
      none  # Returns empty relation (no squaks)
    else
      where(circle: circle).order(created_at: :desc)
    end
  end

  def render_attachment_partial
    'active_storage/blobs/_custom_blob'
  end

  private
  def ensure_content
    # Check if body has text or an attachment tag
    has_text = body.present? && !body&.to_s.strip.empty?
    has_attachment = rich_text_body&.body&.to_s.match?(/<action-text-attachment/)
    return if has_text || has_attachment

    errors.add(:body, "cannot be empty; add text or an attachment")
  end

  # def strip_inline_images_from_body
  #   return if body.blank?
  #   # Remove <img src="data:..."> tags entirely
  #   self.body = body.gsub(/<img\b[^>]*\bsrc\s*=\s*["']\s*data:[^"']*["'][^>]*>/i, "")
  #   # Remove any lingering data: URIs in attributes
  #   self.body = body.gsub(/(["'])\s*data:[^"']*\1/i, '""')
  #
  # end


end

# Schema Information
# create_table "squaks", force: :cascade do |t|
#   t.bigint "user_id", null: false
#   t.datetime "created_at", null: false
#   t.datetime "updated_at", null: false
#   t.bigint "circle_id"
#   t.index ["circle_id"], name: "index_squaks_on_circle_id"
#   t.index ["user_id"], name: "index_squaks_on_user_id"
# end
