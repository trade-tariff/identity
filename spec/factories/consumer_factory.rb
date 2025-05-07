FactoryBot.define do
  factory :consumer do
    id { SecureRandom.uuid }
    return_url { "https://example.com" }
    cookie_domain { "example.com" }
    methods { [:passwordless] }
  end
end
