class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         authentication_keys: [:username]

  has_many :circles, dependent: :destroy  # Circles they own
  has_many :circle_memberships, dependent: :destroy
  has_many :joined_circles, through: :circle_memberships, source: :circle  # Circles they're in
  has_many :squaks, dependent: :destroy
  has_many :user_invites, dependent: :destroy

  has_one :user_profile, dependent: :destroy

  validates :username, presence: true, uniqueness: { case_sensitive: false }

  after_create :create_default_profile

  def select_circle(cid)
    user_profile.update(selected_circle: cid)
  end

  def selected_circle
    return circles.first unless user_profile&.selected_circle.present?
    cid = user_profile.selected_circle
    circle = Circle.find_by(id: cid.to_i)
    if circle.nil?
      # Fallback if a name was ever stored in the profile (old data/rake)
      circle = circles.find_by(name: cid) || joined_circles.find_by(name: cid)
    end
    circle || circles.first
  end

  private
  def create_default_profile
    self.user_profile = UserProfile.new(selected_circle: 0)
  end



end
