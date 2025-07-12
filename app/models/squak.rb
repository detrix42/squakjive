class Squak < ApplicationRecord
  belongs_to :user

  validates :body, presence: true, length: { maximum: 512 }
end
