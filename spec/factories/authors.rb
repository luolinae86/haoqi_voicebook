# frozen_string_literal: true

# == Schema Information
#
# Table name: authors
#
#  id             :bigint           not null, primary key
#  head_img(头像) :string(255)      not null
#  name(作者名)   :string(255)      not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
FactoryBot.define do
  factory :author do
    name { Faker::Book.author }
    head_img { Faker::Internet.url(host: "cdn.example.com", path: "/avatars/#{SecureRandom.hex(4)}.jpg") }
  end
end
