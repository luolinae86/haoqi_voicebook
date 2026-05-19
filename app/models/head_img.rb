# frozen_string_literal: true

# == Schema Information
#
# Table name: head_imgs
#
#  id         :bigint           not null, primary key
#  img_url    :string(255)
#  is_vip     :boolean          default(FALSE)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class HeadImg < ApplicationRecord
  scope :vip, -> { where(is_vip: true) }
  scope :normal, -> { where(is_vip: false) }
  scope :ordered, -> { order(created_at: :asc) }

  def self.random_for(vip:)
    scope = vip ? self.vip : normal
    scope.order("RAND()").first
  end
end
