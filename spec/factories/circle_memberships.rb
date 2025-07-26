FactoryBot.define do
  factory :circle_membership do
    association :user
    association :circle
  end
end
