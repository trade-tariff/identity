source "https://rubygems.org"

ruby file: ".ruby-version"

gem "rails", "~> 8.1.1"

gem "aws-sdk-cognitoidentityprovider"
gem "bootsnap", require: false
gem "faraday"
gem "govuk-components"
gem "govuk_design_system_formbuilder"
gem "importmap-rails"
gem "jwt"
gem "newrelic_rpm"
gem "propshaft"
gem "puma", ">= 5.0"
gem "sidekiq"
gem "sidekiq-scheduler"

group :development, :test do
  gem "brakeman", require: false
  gem "debug"
  gem "dotenv-rails"
end

group :development do
  gem "rubocop-govuk"
  gem "web-console"
end

group :test do
  gem "factory_bot_rails"
  gem "rspec-rails"
end

group :production do
  gem "lograge"
  gem "logstash-event"
end
