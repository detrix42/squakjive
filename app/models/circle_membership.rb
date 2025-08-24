class CircleMembership < ApplicationRecord
  belongs_to :circle
  belongs_to :user
  validates :user_id, uniqueness: { scope: :circle_id }  # No duplicates


  after_create_commit do
    # Append the new member row into this circle’s member list for all viewers
    broadcast_append_to(
      [circle, :members],
      target: "circle-#{circle.id}-user-list",
      partial: "circles/user_item",
      locals: { user: user, circle: circle }
    )

    # Refresh the member count badge
    broadcast_update_to(
      [ circle, :members ],
      target: "circle-members-count-#{circle.id}",
      html: circle.members_count.to_s
    )
  end

  after_destroy_commit do
    # Remove the member row everywhere
    broadcast_remove_to([ circle, :members ],
                        target: "sidebar-user-item-#{user.id}")

    # Refresh the member count badge
    broadcast_update_to(
      [ circle, :members ],
      target: "circle-members-count-#{circle.id}",
      html: circle.members_count.to_s
    )
  end
end
