FactoryBot.define do
  factory :user_invite do
    association :circle
    association :user
  end
end

