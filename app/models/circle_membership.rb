class CircleMembership < ApplicationRecord
  belongs_to :circle
  belongs_to :user
  validates :user_id, uniqueness: { scope: :circle_id }  # No duplicates
end
