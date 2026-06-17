class CircleReadState < ApplicationRecord
  belongs_to :user
  belongs_to :circle

  validates :last_read_at, presence: true
  validates :circle_id, uniqueness: { scope: :user_id }
end