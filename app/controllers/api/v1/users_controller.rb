# frozen_string_literal: true

module Api
  module V1
    class UsersController < BaseController
      # GET /api/v1/users/search?q=alice
      # Used by invite UI to find users by username (partial match).
      def search
        q = params[:q].to_s.strip
        return render json: { users: [] } if q.length < 2

        users = User
          .where.not(id: current_user.id)
          .where("LOWER(username) LIKE ?", "%#{User.sanitize_sql_like(q.downcase)}%")
          .order(:username)
          .limit(20)

        render json: {
          users: users.map { |u| { id: u.id, username: u.username } }
        }
      end
    end
  end
end
