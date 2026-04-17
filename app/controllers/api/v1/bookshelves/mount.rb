# frozen_string_literal: true

# 书架模块挂载
module Api
  module V1
    module Bookshelves
      class Mount < Grape::API
        mount Api::V1::Bookshelves::BookshelfApi
      end
    end
  end
end
