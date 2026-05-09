class Grade < ApplicationRecord
  has_and_belongs_to_many :compilations, join_table: :compilation_grades
  has_and_belongs_to_many :books, join_table: :book_grades

  has_many :recommends, dependent: :destroy

end
