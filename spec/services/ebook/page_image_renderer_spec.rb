# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ebook::PageImageRenderer do
  describe "#normalized_bbox" do
    it "extends full-page crops to include right bleed" do
      renderer = described_class.allocate

      bbox = renderer.send(
        :normalized_bbox,
        { left: 0.0, bottom: 0.0, width: 428.03, height: 612.28 },
        428.03,
        612.28,
        32.0
      )

      expect(bbox).to include(left: 0.0, bottom: 0.0, top: 612.28)
      expect(bbox[:width]).to eq(460.03)
    end
  end

  describe "#flip_rgba_vertically" do
    it "flips cropped rgba pixels vertically without mirroring left and right" do
      renderer = described_class.allocate
      rgba = [
        [255, 0, 0, 255], [0, 255, 0, 255],
        [0, 0, 255, 255], [255, 255, 0, 255]
      ].flatten.pack("C*")

      flipped = renderer.send(:flip_rgba_vertically, rgba, 2, 2)
      pixels = flipped.unpack("C*").each_slice(4).to_a

      expect(pixels).to eq([
        [0, 0, 255, 255],
        [255, 255, 0, 255],
        [255, 0, 0, 255],
        [0, 255, 0, 255]
      ])
    end
  end
end
