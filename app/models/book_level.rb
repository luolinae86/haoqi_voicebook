# == Schema Information
#
# Table name: book_levels
#
#  id         :bigint           not null, primary key
#  name      :string(50)      not null              # 等级名称
#  sn        :integer         not null, default: 0  # 序号
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  deleted_at :datetime         # 软删除
#
class BookLevel < ApplicationRecord
  validates :name, presence: true, length: { maximum: 50 }
  validates :sn, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  
  default_scope { order(sn: :asc) }
  scope :sorted, -> { order(sn: :asc, id: :desc)}
  
  def self.active
    where(deleted_at: nil).order(sn: :asc)
  end
end
