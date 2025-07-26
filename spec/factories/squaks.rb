
FactoryBot.define do
  factory :squak do
    body { Faker::Lorem.sentence(word_count: 10) }
    association :user
    association :circle
  end
end
