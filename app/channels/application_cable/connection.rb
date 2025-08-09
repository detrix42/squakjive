module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      # With Devise, warden is available on the Rack env:
      user = env["warden"]&.user
      return user if user.present?

      # If you use a different auth mechanism, resolve user here.
      reject_unauthorized_connection
    end





  end
end
