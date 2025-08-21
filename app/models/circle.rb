class Circle < ApplicationRecord
  belongs_to :user
  has_many :circle_memberships, dependent: :destroy
  has_many :members, through: :circle_memberships, source: :user  # Members are other users
  has_many :squaks, dependent: :destroy  # Squaks posted to this circle
  validates :name, presence: true, uniqueness: { scope: :user_id }  # Unique per user

  def members_count
    all_members.count
  end

  def visible_members(current_user)
    all_members.where.not(id: current_user.id)
  end

  def all_members
    User.where(id: (members.ids + [user_id]).uniq)
  end


end
