# frozen_string_literal: true

class AddPadImageUrlToSplashAds < ActiveRecord::Migration[8.0]
  def up
    return if column_exists?(:splash_ads, :pad_image_url)

    add_column :splash_ads, :pad_image_url, :string, comment: 'Pad适配的16:9图片URL'
  end

  def down
    remove_column :splash_ads, :pad_image_url if column_exists?(:splash_ads, :pad_image_url)
  end
end
