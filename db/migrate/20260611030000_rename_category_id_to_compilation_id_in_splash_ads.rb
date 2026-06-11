# frozen_string_literal: true

class RenameCategoryIdToCompilationIdInSplashAds < ActiveRecord::Migration[8.0]
  def up
    return unless column_exists?(:splash_ads, :category_id)

    remove_index :splash_ads, :category_id if index_exists?(:splash_ads, :category_id)
    rename_column :splash_ads, :category_id, :compilation_id
    change_column_comment :splash_ads, :compilation_id, '关联合集ID'
    add_index :splash_ads, :compilation_id

    # 同步更新旧数据：link_type 'category' → 'collection'
    execute "UPDATE splash_ads SET link_type = 'collection' WHERE link_type = 'category'"
  end

  def down
    return unless column_exists?(:splash_ads, :compilation_id)

    remove_index :splash_ads, :compilation_id if index_exists?(:splash_ads, :compilation_id)
    rename_column :splash_ads, :compilation_id, :category_id
    change_column_comment :splash_ads, :category_id, '关联分类ID'
    add_index :splash_ads, :category_id

    execute "UPDATE splash_ads SET link_type = 'category' WHERE link_type = 'collection'"
  end
end
