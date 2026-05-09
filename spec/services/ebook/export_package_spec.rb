# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ebook::ExportPackage do
  let(:book) { create(:book, name: "导出包测试", status: :published, content_type: :ebook) }
  let(:output_dir) { Rails.root.join("tmp/spec_export_package_output") }

  after do
    FileUtils.rm_rf(output_dir)
  end

  it "strips trailing carry-over pollution from exported page json" do
    create(
      :ebook_page,
      book: book,
      page_number: 1,
      plain_text: "[BODY] 记者们很快将我围在中间，用相机给我拍照，闪光灯『\n[BODY] 的亮光刺得我睁不开眼睛。\n",
      rich_content: {
        text: "[BODY] 记者们很快将我围在中间，用相机给我拍照，闪光灯『\n[BODY] 的亮光刺得我睁不开眼睛。\n",
        lines: [
          {
            id: "line-1",
            role: "body",
            text: "记者们很快将我围在中间，用相机给我拍照，闪光灯『",
            marker: "[BODY]",
            text_with_role: "[BODY] 记者们很快将我围在中间，用相机给我拍照，闪光灯『\n",
            bbox: { left: 91.56, bottom: 331.71, width: 314.13, height: 12.0, right: 405.68, top: 343.71 }
          },
          {
            id: "line-2",
            role: "body",
            text: "的亮光刺得我睁不开眼睛。",
            marker: "[BODY]",
            text_with_role: "[BODY] 的亮光刺得我睁不开眼睛。\n",
            bbox: { left: 68.03, bottom: 311.21, width: 138.02, height: 11.5, right: 206.05, top: 322.71 }
          }
        ],
        images: [],
        directory: nil
      },
      block_count: 2,
      word_count: 2
    )

    described_class.new(book: book, output_dir: output_dir).call

    payload = JSON.parse(File.read(output_dir.join("pages/page-0001.json")))

    expect(payload["text"]).to include("闪光灯\n")
    expect(payload["text"]).not_to include("闪光灯『")
    expect(payload.dig("lines", 0, "text")).to eq("记者们很快将我围在中间，用相机给我拍照，闪光灯")
  end

  it "strips polluted line prefixes and duplicated carry-over characters from exported page json" do
    create(
      :ebook_page,
      book: book,
      page_number: 1,
      plain_text: "[BODY] 我回到家时，浑身都湿透了，累得一根手指头都动不\n[BODY] IK了了。妈妈坐在客厅的沙发上等我，见我回来了，一把抱\n[BODY] D住了我——这一整个晚上，她都在为我担惊受怕。\n",
      rich_content: {
        text: "[BODY] 我回到家时，浑身都湿透了，累得一根手指头都动不\n[BODY] IK了了。妈妈坐在客厅的沙发上等我，见我回来了，一把抱\n[BODY] D住了我——这一整个晚上，她都在为我担惊受怕。\n",
        lines: [
          {
            id: "line-1",
            role: "body",
            text: "我回到家时，浑身都湿透了，累得一根手指头都动不",
            marker: "[BODY]",
            text_with_role: "[BODY] 我回到家时，浑身都湿透了，累得一根手指头都动不\n",
            bbox: { left: 102.9, bottom: 310.29, width: 257.1, height: 11.5, right: 360.0, top: 321.79 }
          },
          {
            id: "line-2",
            role: "body",
            text: "IK了了。妈妈坐在客厅的沙发上等我，见我回来了，一把抱",
            marker: "[BODY]",
            text_with_role: "[BODY] IK了了。妈妈坐在客厅的沙发上等我，见我回来了，一把抱\n",
            bbox: { left: 31.03, bottom: 288.22, width: 328.97, height: 11.5, right: 360.0, top: 299.72 }
          },
          {
            id: "line-3",
            role: "body",
            text: "D住了我——这一整个晚上，她都在为我担惊受怕。",
            marker: "[BODY]",
            text_with_role: "[BODY] D住了我——这一整个晚上，她都在为我担惊受怕。\n",
            bbox: { left: 31.03, bottom: 266.15, width: 295.61, height: 11.5, right: 326.64, top: 277.65 }
          }
        ],
        images: [],
        directory: nil
      },
      block_count: 3,
      word_count: 3
    )

    described_class.new(book: book, output_dir: output_dir).call

    payload = JSON.parse(File.read(output_dir.join("pages/page-0001.json")))

    expect(payload["text"]).to include("了。妈妈坐在客厅的沙发上等我，见我回来了，一把抱\n")
    expect(payload["text"]).to include("住了我——这一整个晚上，她都在为我担惊受怕。\n")
    expect(payload["text"]).not_to include("IK了了。")
    expect(payload["text"]).not_to include("[BODY] D住了我")
    expect(payload.dig("lines", 1, "text")).to eq("了。妈妈坐在客厅的沙发上等我，见我回来了，一把抱")
    expect(payload.dig("lines", 2, "text")).to eq("住了我——这一整个晚上，她都在为我担惊受怕。")
  end

  it "filters standalone side noise and repairs shifted body line anchors in exported page json" do
    create(
      :ebook_page,
      book: book,
      page_number: 1,
      plain_text: "[BODY] 就变成了一个拇指小人儿，整天待在我的口袋里，当我的\n[BODY] Z\n[BODY] “教育部长”，随时随地监视我的一举一动，成了名副其实\n[BODY] U\n[BODY] 的“装在口袋里的爸爸”。\n[BODY] G\n[BODY] 至于徽章的事情，还得从我昨天上午参观市博物馆\n",
      rich_content: {
        text: "[BODY] 就变成了一个拇指小人儿，整天待在我的口袋里，当我的\n[BODY] Z\n[BODY] “教育部长”，随时随地监视我的一举一动，成了名副其实\n[BODY] U\n[BODY] 的“装在口袋里的爸爸”。\n[BODY] G\n[BODY] 至于徽章的事情，还得从我昨天上午参观市博物馆\n",
        lines: [
          {
            id: "line-1",
            role: "body",
            text: "就变成了一个拇指小人儿，整天待在我的口袋里，当我的",
            marker: "[BODY]",
            text_with_role: "[BODY] 就变成了一个拇指小人儿，整天待在我的口袋里，当我的\n",
            bbox: { left: 79.37, bottom: 376.51, width: 280.63, height: 11.5, right: 360.0, top: 388.01 },
            style: { align: "center", font_size_pt: 11.5, font_family: "FZSSK--GBK1-0" }
          },
          {
            id: "line-2",
            role: "body",
            text: "Z",
            marker: "[BODY]",
            text_with_role: "[BODY] Z\n",
            bbox: { left: 31.03, bottom: 359.38, width: 5.18, height: 8.5, right: 36.22, top: 367.88 },
            style: { align: "left", font_size_pt: 8.5, font_family: "NEU-FZ-Regular" }
          },
          {
            id: "line-3",
            role: "body",
            text: "“教育部长”，随时随地监视我的一举一动，成了名副其实",
            marker: "[BODY]",
            text_with_role: "[BODY] “教育部长”，随时随地监视我的一举一动，成了名副其实\n",
            bbox: { left: 31.03, bottom: 354.19, width: 328.96, height: 11.5, right: 359.99, top: 365.69 },
            style: { align: "left", font_size_pt: 11.5, font_family: "FZSSK--GBK1-0" }
          },
          {
            id: "line-4",
            role: "body",
            text: "U",
            marker: "[BODY]",
            text_with_role: "[BODY] U\n",
            bbox: { left: 31.03, bottom: 348.07, width: 6.13, height: 8.5, right: 37.16, top: 356.57 },
            style: { align: "left", font_size_pt: 8.5, font_family: "NEU-FZ-Regular" }
          },
          {
            id: "line-5",
            role: "body",
            text: "的“装在口袋里的爸爸”。",
            marker: "[BODY]",
            text_with_role: "[BODY] 的“装在口袋里的爸爸”。\n",
            bbox: { left: 31.03, bottom: 332.37, width: 174.86, height: 11.5, right: 205.89, top: 343.87 },
            style: { align: "left", font_size_pt: 11.5, font_family: "FZSSK--GBK1-0" }
          },
          {
            id: "line-6",
            role: "body",
            text: "G",
            marker: "[BODY]",
            text_with_role: "[BODY] G\n",
            bbox: { left: 31.03, bottom: 330.15, width: 6.6, height: 8.5, right: 37.64, top: 338.65 },
            style: { align: "left", font_size_pt: 8.5, font_family: "NEU-FZ-Regular" }
          },
          {
            id: "line-7",
            role: "body",
            text: "至于徽章的事情，还得从我昨天上午参观市博物馆",
            marker: "[BODY]",
            text_with_role: "[BODY] 至于徽章的事情，还得从我昨天上午参观市博物馆\n",
            bbox: { left: 31.03, bottom: 310.29, width: 328.96, height: 11.5, right: 359.99, top: 321.79 },
            style: { align: "left", font_size_pt: 11.5, font_family: "FZSSK--GBK1-0" }
          },
          {
            id: "line-8",
            role: "body",
            text: "好吧，先给故事按下暂停键。",
            marker: "[BODY]",
            text_with_role: "[BODY] 好吧，先给故事按下暂停键。\n",
            bbox: { left: 102.9, bottom: 288.22, width: 87.1, height: 11.5, right: 190.0, top: 299.72 },
            style: { align: "left", font_size_pt: 11.5, font_family: "FZSSK--GBK1-0" }
          }
        ],
        images: [],
        directory: nil
      },
      block_count: 7,
      word_count: 7
    )

    described_class.new(book: book, output_dir: output_dir).call

    payload = JSON.parse(File.read(output_dir.join("pages/page-0001.json")))
    education_line = payload["lines"].find { |line| line["text"].include?("教育部长") }
    pocket_line = payload["lines"].find { |line| line["text"].include?("装在口袋里的爸爸") }
    badge_line = payload["lines"].find { |line| line["text"].include?("至于徽章") }

    expect(payload["text"]).not_to include("[BODY] Z\n")
    expect(payload["text"]).not_to include("[BODY] U\n")
    expect(payload["text"]).not_to include("[BODY] G\n")
    expect(education_line["text"]).to eq("“教育部长”，随时随地监视我的一举一动，成了名副其实")
    expect(education_line.dig("bbox", "left")).to eq(79.37)
    expect(education_line.dig("bbox", "width")).to eq(280.62)
    expect(education_line.dig("style", "align")).to eq("center")
    expect(pocket_line.dig("bbox", "left")).to eq(79.37)
    expect(badge_line.dig("bbox", "left")).to eq(102.9)
  end
end
