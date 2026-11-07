# frozen_string_literal: true

class CreateCharDefinitions < ActiveRecord::Migration[8.0]
  def change
    create_table :char_definitions do |t|
      t.string :character, null: false, comment: '单字'
      # 必须 utf8mb4_bin：表默认的 utf8mb4_unicode_ci 不区分声调，
      # kàn/kān 会被判成同一个键，upsert 时 852 条里有 36 条被合并掉。
      t.string :pinyin, null: false, collation: 'utf8mb4_bin', comment: '读音（带声调符号，如 nǚ）'
      t.json :defs, comment: '低幼释义数组，原样进 dict.json（[释义, 组词：…]）'
      t.string :source, default: 'kids_dict', comment: '来源：kids_dict / qwen / manual'

      t.timestamps
    end

    add_index :char_definitions, :character
    # 多音字每个读音一行（786 个字对应 852 个「字+音」条目）
    add_index :char_definitions, %i[character pinyin], unique: true
  end
end
