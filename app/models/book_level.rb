# == Schema Information
#
# Table name: book_levels
#
#  id             :bigint           not null, primary key
#  name(等级名称) :string(50)       not null
#  sn(序号)       :integer          default(0), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
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
