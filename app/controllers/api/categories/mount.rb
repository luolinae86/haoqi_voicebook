# frozen_string_literal: true

module Api
  module Categories
    class Mount < Grape::API
      mount Api::Categories::CategoryBrowseApi
    end
  end
end
