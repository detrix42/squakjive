class Squak < ApplicationRecord
  belongs_to :user
  belongs_to :circle, optional: true
  validates :body, presence: true, length: { maximum: 512 }

  scope :for_circle, ->(circle) do
    if circle.nil? || (circle.respond_to?(:id) && circle.id == 0)
      none  # Returns empty relation (no squaks)
    else
      where(circle: circle).order(created_at: :desc)
    end
  end


end


# create_table "squaks", force: :cascade do |t|
#   t.bigint "user_id", null: false
#   t.text "body"
#   t.datetime "created_at", null: false
#   t.datetime "updated_at", null: false
#   t.bigint "circle_id"
#   t.index ["circle_id"], name: "index_squaks_on_circle_id"
#   t.index ["user_id"], name: "index_squaks_on_user_id"
# end
