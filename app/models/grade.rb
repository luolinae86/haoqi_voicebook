# == Schema Information
#
# Table name: grades
#
#  id          :bigint           not null, primary key
#  description :string(32)
#  group_name  :string(8)
#  name        :string(16)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class Grade < ApplicationRecord
  has_and_belongs_to_many :compilations, join_table: :compilation_grades
  has_and_belongs_to_many :books, join_table: :book_grades

  has_many :recommends, dependent: :destroy

end
