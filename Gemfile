source "https://mirrors.aliyun.com/rubygems/"

ruby "3.3.0"

gem "rails", "~> 8.0.2"
gem "mysql2", "~> 0.5"
gem "puma", ">= 5.0"
gem "bootsnap", require: false
gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "grape", "~> 2.2"
gem "grape-entity"
gem "rack-cors"
gem "bcrypt", "~> 3.1"
gem "httparty"
gem "kaminari"
gem "kamal"
gem "pdf-reader", "~> 2.15"
gem "rubyzip", "~> 2.3"

group :development, :test do
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "shoulda-matchers"
  gem "simplecov", require: false
  gem "database_cleaner-active_record"
end

group :test do
  gem "matrix"
  gem "webmock"
  gem "timecop"
  gem "prawn"
end
