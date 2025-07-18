class Squak < ApplicationRecord
  belongs_to :user
  belongs_to :circle, optional: true
  validates :body, presence: true, length: { maximum: 512 }

  scope :public_squak, -> { where(circle_id: nil) }

  def self.visible_to(user)
    # Public squaks + those in user's joined circles + user's own squaks
    where(circle_id: nil)
      .or(where(circle_id: user.joined_circles.pluck(:id)))
      .or(where(user_id: user.id))
      .order(created_at: :desc)
  end
end
