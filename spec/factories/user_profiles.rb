# frozen_string_literal: true

# spec/factories/user_profiles.rb
FactoryBot.define do
  factory :user_profile do
    association :user
    selected_circle { nil }
  end
end
