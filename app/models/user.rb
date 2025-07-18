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
  validates :username, presence: true, uniqueness: { case_sensitive: false }
end
