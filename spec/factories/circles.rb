
FactoryBot.define do
  factory :circle do
    name { Faker::Team.name }
    association :user  # Owner of the circle
  end
end
