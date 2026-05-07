# frozen_string_literal: true

# 自动加载 app/entities 下的所有 Entity 文件
Dir[Rails.root.join("app/entities/**/*.rb")].sort.each { |f| require f }
