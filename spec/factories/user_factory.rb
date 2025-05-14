FactoryBot.define do
  factory :user do
    username { SecureRandom.uuid }
    sequence(:email) { |n| "person#{n}@example.com" }
  end
end
