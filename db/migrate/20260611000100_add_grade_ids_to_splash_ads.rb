# frozen_string_literal: true

class AddGradeIdsToSplashAds < ActiveRecord::Migration[8.0]
  def change
    add_column :splash_ads, :grade_ids, :json, comment: '按年级推送时的目标年级ID列表'
  end
end
