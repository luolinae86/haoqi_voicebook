# frozen_string_literal: true

# 图书模块挂载
module Api
  module Books
    class Mount < Grape::API
      mount Api::Books::BookApi
      mount Api::Books::SearchApi
      mount Api::Books::CategoriesApi
    end
  end
end
