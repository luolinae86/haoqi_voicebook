# == Schema Information
#
# Table name: categories
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE)
#  level      :integer          default(1), not null
#  name       :string(255)      not null
#  sn         :integer          default(0)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_categories_on_level  (level)
#
class Category < ApplicationRecord
  has_and_belongs_to_many :compilations, join_table: :compilation_categories
  has_many :books
  has_many :category_subs, dependent: :destroy

  validates :name, presence: true, length: { maximum: 100 }

  scope :by_level, ->(level) { where(level: level) }
  scope :sorted, -> { order(sn: :asc, created_at: :asc) }
  scope :recent, -> { order(created_at: :desc) }

  def can_destroy?
    true
  end

  def can_edit?
    true
  end

  def self.ransackable_attributes(auth_object = nil)
    ["active", "created_at", "description", "id", "id_value", "is_recommended", "level", "name", "sn", "updated_at"]
  end
end
