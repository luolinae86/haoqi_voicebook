# frozen_string_literal: true

class AddPadImageUrlToSplashAds < ActiveRecord::Migration[8.0]
  def change
    add_column :splash_ads, :pad_image_url, :string, comment: 'Pad适配的16:9图片URL'
  end
end
