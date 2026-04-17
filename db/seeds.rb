# frozen_string_literal: true

# VoiceBook 种子数据
# 用于初始化基础数据，执行命令：bin/rails db:seed

puts "🌱 开始创建种子数据..."

# ==================== 年级数据 ====================
puts "📚 创建年级数据..."
grades = [
  { name: "学前", level: 0, description: "3-6岁学前阶段" },
  { name: "一年级", level: 1, description: "小学一年级" },
  { name: "二年级", level: 2, description: "小学二年级" },
  { name: "三年级", level: 3, description: "小学三年级" },
  { name: "四年级", level: 4, description: "小学四年级" },
  { name: "五年级", level: 5, description: "小学五年级" },
  { name: "六年级", level: 6, description: "小学六年级" },
  { name: "七年级", level: 7, description: "初中一年级" },
  { name: "八年级", level: 8, description: "初中二年级" },
  { name: "九年级", level: 9, description: "初中三年级" }
]
grades.each { |g| Grade.find_or_create_by!(name: g[:name], level: g[:level]) { |grade| grade.description = g[:description] } }

# ==================== 分类数据 ====================
puts "📂 创建分类数据..."
categories = [
  { name: "国学经典", icon: "guoxue", description: "中国传统文化经典著作" },
  { name: "儿童文学", icon: "wenxue", description: "优秀儿童文学作品" },
  { name: "科普百科", icon: "kepu", description: "科学知识与百科全书" },
  { name: "历史故事", icon: "lishi", description: "中外历史故事" },
  { name: "英语学习", icon: "english", description: "英语阅读与学习" },
  { name: "绘本漫画", icon: "huiben", description: "精品绘本与漫画" },
  { name: "名人传记", icon: "mingren", description: "名人故事与传记" },
  { name: "诗词歌赋", icon: "shici", description: "古诗词与现代诗歌" },
  { name: "童话寓言", icon: "tonghua", description: "童话故事与寓言" },
  { name: "安全教育", icon: "anquan", description: "儿童安全教育" }
]
categories.each { |c| Category.find_or_create_by!(name: c[:name]) { |cat| cat.assign_attributes(c) } }

# ==================== 阅读分级数据 ====================
puts "📊 创建阅读分级数据..."
levels = [
  { name: "启蒙级", level: 1, description: "适合3-5岁儿童，以图画为主" },
  { name: "入门级", level: 2, description: "适合5-7岁儿童，图文并茂" },
  { name: "基础级", level: 3, description: "适合7-9岁儿童，开始独立阅读" },
  { name: "提高级", level: 4, description: "适合9-11岁儿童，章节阅读" },
  { name: "进阶级", level: 5, description: "适合11-13岁少年，深度阅读" },
  { name: "高级", level: 6, description: "适合13-15岁少年，经典阅读" }
]
levels.each { |l| ReadingLevel.find_or_create_by!(name: l[:name], level: l[:level]) { |rl| rl.description = l[:description] } }

# ==================== 排行榜数据 ====================
puts "🏆 创建排行榜数据..."
rankings = [
  { name: "热度榜", ranking_type: "hot", description: "最受欢迎的图书" },
  { name: "高分榜", ranking_type: "high_score", description: "评分最高的图书" },
  { name: "上新榜", ranking_type: "new_arrival", description: "最新上架的图书" },
  { name: "大奖榜", ranking_type: "award", description: "获得大奖的图书" },
  { name: "名著榜", ranking_type: "classic", description: "经典名著推荐" }
]
rankings.each { |r| Ranking.find_or_create_by!(name: r[:name], ranking_type: r[:ranking_type]) { |rank| rank.description = r[:description] } }

# ==================== 热门搜索 ====================
puts "🔍 创建热门搜索数据..."
hot_keywords = %w[西游记 三国演义 安徒生童话 格林童话 十万个为什么 弟子规 唐诗三百首 成语故事 伊索寓言 小王子]
hot_keywords.each_with_index do |kw, i|
  HotSearch.find_or_create_by!(keyword: kw) { |hs| hs.search_count = rand(100..1000); hs.sort_order = i + 1 }
end

# ==================== API 认证 ====================
puts "🔑 创建 API 认证数据..."
ApiAuth.find_or_create_by!(access_key_id: "voicebook_dev_key") do |auth|
  auth.access_key_secret = "voicebook_dev_secret"
  auth.name = "VoiceBook开发环境"
end

puts "✅ 种子数据创建完成！"
