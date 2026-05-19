# frozen_string_literal: true

# == Schema Information
#
# Table name: book_stats
#
#  book_id             :bigint           not null, comment: '图书ID'
#  total_readers       :integer          not null, default(0), comment: '总阅读人数(去重)'
#  total_reads         :integer          not null, default(0), comment: '总阅读次数'
#  total_duration_seconds:integer       not null, default(0), comment: '总阅读时长(秒)'
#  total_words_read    :integer          not null, default(0), comment: '总阅读字数'
#  completed_count     :integer          not null, default(0), comment: '完读人数'
#  completion_rate     :float            not null, default(0.0), comment: '完读率'
#  weekly_readers      :integer          not null, default(0), comment: '近7天阅读人数'
#  weekly_reads        :integer          not null, default(0), comment: '近7天阅读次数'
#  monthly_readers     :integer          not null, default(0), comment: '近30天阅读人数'
#  monthly_reads       :integer          not null, default(0), comment: '近30天阅读次数'
#
class BookStats < ApplicationRecord
  belongs_to :book

  scope :by_weekly_readers, -> { order(weekly_readers: :desc) }
  scope :by_monthly_readers, -> { order(monthly_readers: :desc) }
  scope :by_completion_rate, -> { where('total_readers > 0').order(completion_rate: :desc) }
  scope :by_rating, -> { joins(:book).merge(Book.order(rating: :desc)) }

  def self.find_or_create_for(book_id)
    find_or_create_by!(book_id: book_id)
  end
end
