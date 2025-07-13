FactoryBot.define do
  factory :user do
    email { "user#{rand(1000)}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
  end
end
