class Attachment < ApplicationRecord
  has_one_attached :file, dependent: :purge_later
end
