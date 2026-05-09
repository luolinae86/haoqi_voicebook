# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ebook::PdfImporter do
  let(:book) { create(:book, name: "PDF 导入测试", status: :published, content_type: :ebook) }
  let(:files) { create_sample_ebook_pdf }
  let(:storage_root) { Rails.public_path.join("system/spec_ebooks") }
  let(:rendered_png) { Base64.decode64(PdfFixtureHelper::SAMPLE_PNG) }
  let(:page_renderer) do
    instance_double(
      Ebook::PageImageRenderer,
      available?: true,
      render_crop: {
        bytes: rendered_png,
        extension: "png",
        mime_type: "image/png",
        image_width: 120,
        image_height: 120,
        filter: "QuartzPageRender"
      },
      close: true
    )
  end

  after do
    cleanup_sample_ebook_pdf(files)
    FileUtils.rm_rf(storage_root)
  end

  it "imports pdf into structured ebook pages" do
    described_class.new(
      book: book,
      pdf_path: files[:pdf].path,
      source_filename: "sample-ebook.pdf",
      storage_root: storage_root,
      page_renderer: page_renderer
    ).call

    book.reload
    first_page = book.ebook_pages.find_by!(page_number: 1)
    content = first_page.rich_content.deep_symbolize_keys

    expect(book.import_status).to eq("ready")
    expect(book.page_count).to eq(2)
    expect(book.word_count).to be_positive
    expect(book.ebook_pages.count).to eq(2)
    expect(content[:text]).to include("[TITLE] Chapter 1 Luminous Badge\n")
    expect(content[:text]).to include("[BODY] This is the first page body content for importer verification.\n")
    expect(content[:lines].first[:role]).to eq("heading")
    expect(content[:lines].first[:style][:font_family]).to be_present
    expect(content[:images].size).to eq(1)
    expect(content[:directory][:title]).to eq("Chapter 1 Luminous Badge")

    image_block = content[:images].first
    expect(image_block[:image_url]).to start_with("/system/spec_ebooks/")
    expect(image_block[:mime_type]).to eq("image/png")
    expect(page_renderer).not_to have_received(:render_crop)
    expect(File).to exist(Rails.public_path.join(image_block[:image_url].delete_prefix("/")))
  end

  it "can force native pdf pages to export as full-page images while keeping the chapter directory" do
    described_class.new(
      book: book,
      pdf_path: files[:pdf].path,
      source_filename: "sample-ebook.pdf",
      storage_root: storage_root,
      page_renderer: page_renderer,
      force_image_pages: true
    ).call

    book.reload
    first_page = book.ebook_pages.find_by!(page_number: 1)
    content = first_page.rich_content.deep_symbolize_keys

    expect(content[:text]).to eq("")
    expect(content[:lines]).to eq([])
    expect(content[:directory]).to include(title: "Chapter 1 Luminous Badge")
    expect(content[:images]).to contain_exactly(
      hash_including(
        role: "hero_image",
        mime_type: "image/png",
        bbox: hash_including(
          left: 0.0,
          bottom: 0.0,
          right: be > 0,
          top: be > 0
        )
      )
    )
    expect(page_renderer).to have_received(:render_crop).at_least(:once)
  end
end
