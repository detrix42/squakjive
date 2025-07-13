FactoryBot.define do
  factory :user do
    after(:build) do |user|
      rnum = rand(1000)
      user.email = "user#{rnum}@example.com"
      user.username = "username#{rnum}"
      user.password = "password123"
      user.password_confirmation = "password123"
    end
  end
end
