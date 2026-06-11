# frozen_string_literal: true

class RenameCategoryIdToCollectionIdInSplashAds < ActiveRecord::Migration[8.0]
  def up
    return unless column_exists?(:splash_ads, :category_id)

    remove_index :splash_ads, :category_id if index_exists?(:splash_ads, :category_id)
    rename_column :splash_ads, :category_id, :collection_id
    change_column_comment :splash_ads, :collection_id, '关联合集ID'
    add_index :splash_ads, :collection_id

    # 同步更新旧数据：link_type 'category' → 'collection'
    execute "UPDATE splash_ads SET link_type = 'collection' WHERE link_type = 'category'"
  end

  def down
    return unless column_exists?(:splash_ads, :collection_id)

    remove_index :splash_ads, :collection_id if index_exists?(:splash_ads, :collection_id)
    rename_column :splash_ads, :collection_id, :category_id
    change_column_comment :splash_ads, :category_id, '关联分类ID'
    add_index :splash_ads, :category_id

    execute "UPDATE splash_ads SET link_type = 'category' WHERE link_type = 'collection'"
  end
end
