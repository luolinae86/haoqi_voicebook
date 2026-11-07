# frozen_string_literal: true

namespace :picture_book do
  desc '把 kids-dict.json 灌进 char_definitions（幂等 upsert）'
  task seed_dict: :environment do
    count = PictureBook::KidsDict.import!
    puts "char_definitions: #{count} 条（字+读音）"
  end
end
