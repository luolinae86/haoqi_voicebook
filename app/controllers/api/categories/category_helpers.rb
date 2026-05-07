# frozen_string_literal: true

# Category 模块辅助方法
module Api
  module Categories
    module CategoryHelpers
      extend Grape::API::Helpers

      # 获取分类列表
      def categories_for(parent_id: nil)
        if parent_id.present?
          Category.where(parent_id: parent_id).ordered
        else
          Category.roots.ordered
        end
      end
    end
  end
end
