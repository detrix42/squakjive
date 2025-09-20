class SquaksChannel < ApplicationCable::Channel
  def subscribed
    reject unless current_user # extra safety
    stream_from "squaks"


    $redis.sadd?("squaks_channel_users", current_user.id)
    broadcast_count

  end

  def unsubscribed
    return unless current_user

    $redis.srem?("squaks_channel_users", current_user.id)
    broadcast_count

  end

  private

  def broadcast_count
    count = $redis.scard("squaks_channel_users")
    ActionCable.server.broadcast("squaks", { connected_user_count: count })
  end

end
