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

  describe "#display_crop_pixels" do
    let(:renderer) do
      instance = described_class.allocate
      instance.instance_variable_set(:@scale, 2.0)
      instance
    end

    it "maps a full raw page box to the full display page for Rotate=90" do
      pixels = renderer.send(
        :display_crop_pixels,
        { left: 0.0, bottom: 0.0, width: 595.22, height: 842.0, top: 842.0 },
        595.22, 842.0, 90
      )

      expect(pixels[0]).to eq(0)
      expect(pixels[1]).to eq(0)
      expect(pixels[2]).to eq((842.0 * 2).ceil) # display width = raw height
      expect(pixels[3]).to eq((595.22 * 2).ceil) # display height = raw width
    end

    it "converts a raw-space sub-box to display-space pixels for Rotate=90" do
      pixels = renderer.send(
        :display_crop_pixels,
        { left: 100.0, bottom: 200.0, width: 50.0, height: 60.0, top: 260.0 },
        595.22, 842.0, 90
      )

      # Rotate=90: display x = raw bottom, display top = raw left, axes swapped
      expect(pixels).to eq([400, 200, 120, 100])
    end

    it "keeps dimensions and mirrors axes for Rotate=180" do
      pixels = renderer.send(
        :display_crop_pixels,
        { left: 100.0, bottom: 200.0, width: 50.0, height: 60.0, top: 260.0 },
        595.22, 842.0, 180
      )

      expect(pixels[2]).to eq(100) # width preserved
      expect(pixels[3]).to eq(120) # height preserved
    end

    it "converts a raw-space sub-box to display-space pixels for Rotate=270" do
      pixels = renderer.send(
        :display_crop_pixels,
        { left: 100.0, bottom: 200.0, width: 50.0, height: 60.0, top: 260.0 },
        595.22, 842.0, 270
      )

      # Rotate=270: display x = raw_height - top, display top = raw_width - right
      expect(pixels[0]).to eq(((842.0 - 260.0) * 2).floor)
      expect(pixels[1]).to eq(((595.22 - 150.0) * 2).floor)
      expect(pixels[2]).to eq(120)
      expect(pixels[3]).to eq(100)
    end
  end

  describe "#read_page_rotation" do
    let(:renderer) do
      instance = described_class.allocate
      instance.instance_variable_set(:@pdf_path, Pathname.new("/tmp/whatever.pdf"))
      instance.instance_variable_set(:@rotation_cache, {})
      instance
    end

    it "parses poppler 'Page N rot' lines, tolerating non-UTF8 metadata" do
      allow(renderer).to receive(:pdfinfo_path).and_return("/usr/bin/pdfinfo")
      stdout = "Title:           \xC3\x2D\xFF binary title\nPage    2 rot:   90\n".dup.force_encoding("BINARY")
      allow(Open3).to receive(:capture3).and_return([stdout, "", instance_double(Process::Status, success?: true)])

      expect(renderer.send(:read_page_rotation, 2)).to eq(90)
    end

    it "returns 0 when pdfinfo is unavailable" do
      allow(renderer).to receive(:pdfinfo_path).and_return(nil)

      expect(renderer.send(:read_page_rotation, 2)).to eq(0)
    end
  end

  describe "rotated full-page rendering (pdftocairo, integration)" do
    def rotated_pdf_fixture
      pdf_file = Tempfile.new(%w[rotated-spread .pdf])
      image_file = Tempfile.new(%w[spread-image .png])
      image_file.binmode
      image_file.write(Base64.decode64(PdfFixtureHelper::SAMPLE_PNG))
      image_file.flush
      # Landscape spread content on a portrait MediaBox, then force Rotate via post-processing
      Prawn::Document.generate(pdf_file.path, page_size: [595.22, 842], margin: 0) do |pdf|
        pdf.text "spread marker"
      end
      pdf_file.close
      bytes = File.binread(pdf_file.path)
      rotated = bytes.sub("/Type /Pages", "/Type /Pages /Rotate 90")
      File.binwrite(pdf_file.path, rotated)
      pdf_file
    rescue StandardError
      nil
    end

    it "renders the full rotated page in display orientation" do
      skip "pdftocairo/pdfinfo not available" unless system("which pdftocairo > /dev/null 2>&1") && system("which pdfinfo > /dev/null 2>&1")

      pdf_file = rotated_pdf_fixture
      skip "could not build rotated fixture" unless pdf_file && File.size(pdf_file.path).positive?

      renderer = described_class.new(pdf_path: pdf_file.path, backend: "pdftocairo")
      result = renderer.render_crop(
        page_number: 1,
        page_width: 595.22,
        page_height: 842.0,
        bbox: { left: 0.0, bottom: 0.0, width: 595.22, height: 842.0 }
      )

      # Rotate=90: display raster must be landscape (width > height), not the clipped square
      expect(result[:image_width]).to be > result[:image_height]
      expect(result[:bytes].byteslice(16, 8).unpack("N2")).to eq([result[:image_width], result[:image_height]])
    ensure
      pdf_file&.close!
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
