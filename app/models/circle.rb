class Circle < ApplicationRecord
  belongs_to :user
  has_many :circle_memberships, dependent: :destroy
  has_many :members, through: :circle_memberships, source: :user  # Members are other users
  has_many :squaks  # Squaks posted to this circle
  validates :name, presence: true, uniqueness: { scope: :user_id }  # Unique per user

  def members_count
    members.count
  end

  def visible_members(current_user)
    members.where.not(id: current_user.id)
  end
end
