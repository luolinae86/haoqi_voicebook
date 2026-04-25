# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ebook::PdfImporter do
  let(:importer) { described_class.allocate }
  let(:page) { instance_double("PDF::Reader::Page", width: 428.03, height: 612.28) }
  let(:heading_line) do
    {
      role: "heading",
      bbox: {
        left: 80.0,
        right: 240.0,
        bottom: 442.0,
        top: 472.0
      }
    }
  end

  def build_image(label:, left:, bottom:, width:, height:, image_mask: false, filter: :DCTDecode)
    {
      label: label,
      left: left,
      bottom: bottom,
      width: width,
      height: height,
      xobject: instance_double("PDF::Reader::Stream", hash: { ImageMask: image_mask, Filter: [filter] })
    }
  end

  describe "#select_primary_images" do
    it "prefers a top logo image over side decorative strips" do
      side_strip = build_image(label: "Im-side", left: 0.5, bottom: 220.0, width: 57.6, height: 152.0)
      top_logo = build_image(label: "Im-top", left: 188.0, bottom: 539.0, width: 63.7, height: 52.1)

      selected = importer.send(:select_primary_images, page, [side_strip, top_logo], text_lines: [heading_line])

      expect(selected.size).to eq(1)
      expect(selected.first[:label]).to eq("Im-top")
    end

    it "rejects small image-mask artifacts that are likely converted text" do
      side_strip = build_image(label: "Im-side", left: 370.0, bottom: 221.0, width: 57.6, height: 152.0)
      small_mask = build_image(label: "Im-mask", left: 160.0, bottom: 260.0, width: 83.0, height: 64.0, image_mask: true, filter: :CCITTFaxDecode)

      selected = importer.send(:select_primary_images, page, [side_strip, small_mask], text_lines: [heading_line])

      expect(selected).to be_empty
    end

    it "keeps a title-adjacent mask logo instead of filtering it as text" do
      side_strip = build_image(label: "Im-side", left: 370.0, bottom: 221.0, width: 57.6, height: 152.0)
      top_mask_logo = build_image(label: "Im-logo", left: 219.0, bottom: 429.0, width: 83.0, height: 64.0, image_mask: true, filter: :CCITTFaxDecode)

      selected = importer.send(:select_primary_images, page, [side_strip, top_mask_logo], text_lines: [heading_line])

      expect(selected.size).to eq(1)
      expect(selected.first[:label]).to eq("Im-logo")
    end

    it "uses full-page composite rendering when a full raster and large mask coexist" do
      full_page_raster = build_image(label: "Im-base", left: -0.1, bottom: -0.5, width: 427.9, height: 612.2)
      large_mask = build_image(label: "Im-mask", left: 76.5, bottom: 109.7, width: 281.6, height: 389.6, image_mask: true, filter: :CCITTFaxDecode)

      selected = importer.send(:select_primary_images, page, [full_page_raster, large_mask], text_lines: [])

      expect(selected.size).to eq(1)
      expect(selected.first[:force_render]).to eq(true)
      expect(selected.first[:visible_box]).to eq(left: 0.0, bottom: 0.0, width: page.width, height: page.height)
    end
  end

  describe "#text_over_image_page_candidate" do
    it "treats full-page image with overlaid text as a single rendered page image" do
      full_page_raster = build_image(label: "Im-full", left: 0.0, bottom: 0.0, width: 428.03, height: 612.28)
      text_lines = 8.times.map do |index|
        {
          bbox: {
            left: 120.0,
            right: 280.0,
            bottom: 420.0 - (index * 24),
            top: 432.0 - (index * 24)
          }
        }
      end

      selected = importer.send(:text_over_image_page_candidate, page, [full_page_raster], text_lines)

      expect(selected).to be_present
      expect(selected[:force_render]).to eq(true)
      expect(selected[:overlay_page]).to eq(true)
      expect(selected[:visible_box]).to eq(left: 0.0, bottom: 0.0, width: page.width, height: page.height)
    end
  end
end
