namespace :db do
  desc "Populate test environment with sample users, profiles, circles, circle_memberships, and squaks"
  task populate_test_data: :environment do
    require 'faker'
    include FactoryBot::Syntax::Methods

    # Clear existing data (optional, use with caution in development)
    begin
      CircleMembership.delete_all
      Squak.delete_all
      Circle.delete_all
      UserProfile.delete_all
      User.delete_all
    rescue StandardError => e
      puts "Error clearing data: #{e.message}"
      raise
    end

    # Create 10 users with profiles
    users = []
    begin
      users = create_list(:user, 10) do |user|
        create(:user_profile, user: user)
      end
    rescue ActiveRecord::RecordInvalid => e
      puts "Error creating users: #{e.message}"
      raise
    end

    # Create 3-5 circles per user
    users.each do |user|
      begin
        create_list(:circle, rand(3..5), user: user).each do |circle|
          # Add 2-5 random members to each circle
          other_users = (users - [user]).sample(rand(2..5))
          other_users.each { |member| create(:circle_membership, circle: circle, user: member) }
          # Create 10-20 squaks per circle
          create_list(:squak, rand(10..20), circle: circle, user: users.sample)
        end
      rescue ActiveRecord::RecordInvalid => e
        puts "Error creating circles or squaks for user #{user.id}: #{e.message}"
        raise
      end
    end

    # Assign random selected_circle (name) to each user profile
    users.each do |user|
      begin
        available_circles = user.circles + user.circle_memberships.map(&:circle)
        if available_circles.any?
          user.user_profile.update(selected_circle: available_circles.sample.name)
        end
      rescue StandardError => e
        puts "Error updating user profile for user #{user.id}: #{e.message}"
        raise
      end
    end

    puts "Created #{User.count} users, #{UserProfile.count} profiles, #{Circle.count} circles, #{CircleMembership.count} circle_memberships, #{Squak.count} squaks"
  end
end
