# frozen_string_literal: true

# RSpec 配置文件
# 包含 FactoryBot、SimpleCov、DatabaseCleaner、Shoulda 等测试工具的配置

# 启动代码覆盖率统计（必须在 require rails 之前）
require "simplecov"
SimpleCov.start "rails" do
  add_filter "/spec/"
  add_filter "/config/"
  add_filter "/vendor/"
  add_group "Models", "app/models"
  add_group "Controllers", "app/controllers"
  add_group "API", "app/controllers/api"
  minimum_coverage 80
end

require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"
require "shoulda/matchers"
require "database_cleaner/active_record"
require "webmock/rspec"
require "sidekiq/testing"
Sidekiq::Testing.fake!

# 自动加载 spec/support 目录下的所有文件
Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |f| require f }

# 确保测试数据库 schema 是最新的
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

# ==================== Shoulda Matchers 配置 ====================
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

# ==================== RSpec 主配置 ====================
RSpec.configure do |config|
  # 使用 FactoryBot 的简写方法（如 create(:user) 而不是 FactoryBot.create(:user)）
  config.include FactoryBot::Syntax::Methods

  # 自动推断 spec 类型
  config.infer_spec_type_from_file_location!

  # 过滤 Rails gem 的 backtrace
  config.filter_rails_from_backtrace!

  # ==================== DatabaseCleaner 配置 ====================
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  # ==================== API 测试辅助方法 ====================
  config.include(Module.new do
    # 解析 JSON 响应体
    def json_response
      JSON.parse(response.body, symbolize_names: true)
    end
  end, type: :request)
end
