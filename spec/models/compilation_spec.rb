# frozen_string_literal: true

# == Schema Information
#
# Table name: compilations
#
#  id                                                      :bigint           not null, primary key
#  author(作者)                                            :string(255)
#  banner_image_name(合辑banner图片文件名)                 :string(255)
#  banner_image_url(合辑banner图片URL (1500x932, <=500KB)) :string(255)
#  content_description(合辑简介（富文本/Markdown）)        :text(65535)
#  description(内容简介)                                   :text(65535)
#  editor_recommendation(编辑推荐语（15字以内）)           :string(15)
#  intro_image_name(图片简介文件名)                        :string(255)
#  intro_image_url(图片简介URL)                            :string(255)
#  landscape_cover_name(横图封面文件名)                    :string(255)
#  landscape_cover_url(横图封面URL (1125x540, <=500KB))    :string(255)
#  name(合辑名称)                                          :string(255)      not null
#  portrait_cover_name                                     :string(255)
#  portrait_cover_url                                      :string(255)
#  publisher(出版社)                                       :string(255)
#  square_cover_name                                       :string(255)
#  square_cover_url                                        :string(255)
#  tags(内容标签)                                          :string(255)
#  total_count(合辑总集数)                                 :integer          default(0)
#  created_at                                              :datetime         not null
#  updated_at                                              :datetime         not null
#
# Indexes
#
#  index_compilations_on_name  (name) UNIQUE
#
require "rails_helper"

RSpec.describe Compilation, type: :model do
  describe "associations" do
    it { is_expected.to have_and_belong_to_many(:grades) }
    it { is_expected.to have_and_belong_to_many(:categories) }
    it { is_expected.to have_and_belong_to_many(:books) }
    it { is_expected.to have_many(:contents) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
  end

  describe "实例方法" do
    describe "#covers_complete?" do
      it "当三个封面都存在时返回 true" do
        compilation = Compilation.new(
          name: "Test",
          landscape_cover_url: "http://example.com/l.jpg",
          portrait_cover_url: "http://example.com/p.jpg",
          square_cover_url: "http://example.com/s.jpg"
        )
        expect(compilation.covers_complete?).to be true
      end

      it "当缺少封面时返回 false" do
        compilation = Compilation.new(name: "Test", landscape_cover_url: nil)
        expect(compilation.covers_complete?).to be false
      end
    end

    describe "#main_cover_url" do
      it "优先返回 landscape_cover_url" do
        compilation = Compilation.new(
          name: "Test",
          landscape_cover_url: "http://example.com/l.jpg",
          banner_image_url: "http://example.com/b.jpg"
        )
        expect(compilation.main_cover_url).to eq("http://example.com/l.jpg")
      end

      it "没有 landscape 时返回 banner_image_url" do
        compilation = Compilation.new(
          name: "Test",
          landscape_cover_url: nil,
          banner_image_url: "http://example.com/b.jpg"
        )
        expect(compilation.main_cover_url).to eq("http://example.com/b.jpg")
      end
    end
  end
end
