FactoryBot.define do
  factory :consumer do
    id { SecureRandom.uuid }
    success_url { "https://example.com" }
    failure_url { "https://example.com/invalid" }
    cookie_domain { "example.com" }
    methods { [:passwordless] }
  end
end
