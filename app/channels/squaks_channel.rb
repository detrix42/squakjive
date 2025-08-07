class SquaksChannel < ApplicationCable::Channel
  def subscribed
    stream_from "squaks"
    $redis.sadd("squaks_channel_users", current_user.id)
    broadcast_count

  end

  def unsubscribed
    $redis.srem("squaks_channel_users", current_user.id)
    broadcast_count

  end

  private

  def broadcast_count
    count = $redis.scard("squaks_channel_users")
    ActionCable.server.broadcast("squaks", { connected_user_count: count })
  end

end
