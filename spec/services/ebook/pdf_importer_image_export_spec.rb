# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ebook::PdfImporter do
  let(:importer) { described_class.allocate }
  let(:page) { instance_double("PDF::Reader::Page", number: 8, width: 428.03, height: 612.28, objects: {}) }
  let(:renderer) do
    instance_double(
      Ebook::PageImageRenderer,
      available?: true,
      render_crop: {
        bytes: "png-bytes",
        extension: "png",
        mime_type: "image/png",
        image_width: 320,
        image_height: 240,
        filter: "QuartzPageRender"
      }
    )
  end
  let(:exporter) { instance_double(Ebook::ImageExporter) }

  before do
    importer.instance_variable_set(:@public_root, Rails.root.join("public"))
    importer.instance_variable_set(:@storage_root, Rails.root.join("tmp/spec_image_export"))
    allow(Ebook::ImageExporter).to receive(:new).and_return(exporter)
    allow(exporter).to receive(:export)
    allow(exporter).to receive(:export_rendered)
  end

  after do
    FileUtils.rm_rf(Rails.root.join("tmp/spec_image_export"))
  end

  def build_image(mask:)
    {
      left: 100.0,
      bottom: 420.0,
      width: 80.0,
      height: 60.0,
      xobject: instance_double("PDF::Reader::Stream", hash: { ImageMask: mask, Filter: [mask ? :CCITTFaxDecode : :DCTDecode] }),
      visible_box: { left: 100.0, bottom: 420.0, width: 80.0, height: 60.0 },
      image_mask: mask
    }
  end

  it "exports normal raster images directly from the xobject" do
    image = build_image(mask: false)
    allow(importer).to receive(:select_primary_images).and_return([image])
    allow(exporter).to receive(:export).and_return(
      image_url: "/system/test/page_8/image_1.jpg",
      mime_type: "image/jpeg",
      image_width: 120,
      image_height: 90,
      filter: "DCTDecode"
    )

    blocks = importer.send(:build_image_blocks, page, [image], renderer: renderer, text_lines: [])

    expect(blocks.first[:mime_type]).to eq("image/jpeg")
    expect(exporter).to have_received(:export).once
    expect(exporter).not_to have_received(:export_rendered)
    expect(renderer).not_to have_received(:render_crop)
  end

  it "renders image-mask candidates from the page crop" do
    image = build_image(mask: true)
    allow(importer).to receive(:select_primary_images).and_return([image])
    allow(exporter).to receive(:export_rendered).and_return(
      image_url: "/system/test/page_8/image_1.png",
      mime_type: "image/png",
      image_width: 320,
      image_height: 240,
      filter: "QuartzPageRender"
    )

    blocks = importer.send(:build_image_blocks, page, [image], renderer: renderer, text_lines: [])

    expect(blocks.first[:mime_type]).to eq("image/png")
    expect(renderer).to have_received(:render_crop).once
    expect(exporter).to have_received(:export_rendered).once
    expect(exporter).not_to have_received(:export)
  end
end
