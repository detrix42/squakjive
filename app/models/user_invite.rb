class UserInvite < ApplicationRecord
  belongs_to :circle
  belongs_to :user

  # Ensure these partial paths and target IDs match your views
  after_create_commit do
    broadcast_append_to(
      [user, :user_invites],
      target: "user-invites-list",
      partial: "dashboard/user_invites",
      locals: { invite: self }
    )
    MobileRealtimeBroadcast.invite_created(self)
  end

  after_destroy_commit do
    broadcast_remove_to(
      [user, :user_invites],
      target: self
    )
    MobileRealtimeBroadcast.invite_removed(user_id: user_id, invite_id: id)
  end
end
