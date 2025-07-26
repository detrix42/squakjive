FactoryBot.define do
  factory :user do
    sequence(:username) { |n| "#{Faker::Internet.username}#{n}" }  # Unique username
    sequence(:email) { |n| "user#{n}@#{Faker::Internet.domain_name}" }  # Unique email
    password { 'password123' }
  end
end
