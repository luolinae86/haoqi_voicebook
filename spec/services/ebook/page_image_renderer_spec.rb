# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ebook::PageImageRenderer do
  describe "#configure_backend!" do
    it "prefers pdftocairo in auto mode when available" do
      renderer = described_class.allocate
      renderer.instance_variable_set(:@backend_preference, "auto")
      renderer.instance_variable_set(:@backend, nil)
      allow(renderer).to receive(:pdftocairo_available?).and_return(true)
      allow(renderer).to receive(:darwin_platform?).and_return(true)
      allow(renderer).to receive(:open_core_graphics_document!)

      renderer.send(:configure_backend!)

      expect(renderer.send(:available?)).to eq(true)
      expect(renderer.instance_variable_get(:@backend)).to eq(:pdftocairo)
      expect(renderer).not_to have_received(:open_core_graphics_document!)
    end

    it "does not try to load CoreGraphics on non-darwin hosts when pdftocairo is unavailable" do
      renderer = described_class.allocate
      renderer.instance_variable_set(:@backend_preference, "auto")
      renderer.instance_variable_set(:@backend, nil)
      allow(renderer).to receive(:pdftocairo_available?).and_return(false)
      allow(renderer).to receive(:darwin_platform?).and_return(false)
      allow(renderer).to receive(:open_core_graphics_document!)

      renderer.send(:configure_backend!)

      expect(renderer.send(:available?)).to eq(false)
      expect(renderer).not_to have_received(:open_core_graphics_document!)
    end
  end

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

  describe "#render_crop" do
    it "dispatches to the pdftocairo backend when selected" do
      renderer = described_class.allocate
      renderer.instance_variable_set(:@backend, :pdftocairo)
      allow(renderer).to receive(:render_with_pdftocairo).and_return(filter: described_class::PDFTOCAIRO_FILTER)

      result = renderer.render_crop(
        page_number: 1,
        page_width: 428.03,
        page_height: 612.28,
        bbox: { left: 0.0, bottom: 0.0, width: 100.0, height: 100.0 }
      )

      expect(result[:filter]).to eq(described_class::PDFTOCAIRO_FILTER)
      expect(renderer).to have_received(:render_with_pdftocairo)
    end
  end
end
