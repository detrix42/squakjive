class UserInvite < ApplicationRecord
  belongs_to :circle
  belongs_to :user

  # Ensure these partial paths and target IDs match your views
  after_create_commit do
    broadcast_append_to(
      "user-invites-#{user_id}",
      target: "user-invites-list",
      partial: "dashboard/user_invites",
      locals: { invite: self }
    )
  end

  after_destroy_commit do
    broadcast_remove_to(
      "user-invites-#{user_id}",
      target: self
    )
  end
end
