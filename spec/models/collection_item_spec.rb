# frozen_string_literal: true

require "rails_helper"

RSpec.describe CollectionItem, type: :model do
  # 关联测试
  describe "associations" do
    it { is_expected.to belong_to(:collection) }
    it { is_expected.to belong_to(:book) }
  end

  # 验证测试
  describe "validations" do
    subject { create(:collection_item) }

    it { is_expected.to validate_uniqueness_of(:collection_id).scoped_to(:book_id).with_message("该图书已在合集中") }
    it { is_expected.to validate_presence_of(:sort_order) }
  end

  # 作用域测试
  describe "scopes" do
    describe ".ordered" do
      it "按 sort_order 升序排列" do
        collection = create(:collection)
        item3 = create(:collection_item, collection: collection, sort_order: 3)
        item1 = create(:collection_item, collection: collection, sort_order: 1)
        item2 = create(:collection_item, collection: collection, sort_order: 2)

        expect(collection.collection_items.ordered).to eq([item1, item2, item3])
      end
    end
  end
end
