# frozen_string_literal: true

require "rails_helper"
require "prawn"
require "tempfile"

RSpec.describe EpubExportWorker do
  let(:book) { create(:book, status: :published, content_type: :ebook, import_status: :not_imported) }
  let(:oss_service) { instance_double(AliyunOssService) }
  let(:pdf_oss_key) { "pdfs/test-book.pdf" }

  after do
    FileUtils.rm_rf(Rails.public_path.join("system/ebooks"))
  end

  def create_test_pdf(path)
    Prawn::Document.generate(path, margin: 48) do |pdf|
      pdf.font_size 24
      pdf.text "Chapter 1", align: :center
      pdf.move_down 18
      pdf.font_size 12
      pdf.text "This is the first page body content for importer verification."
    end
  end

  describe "#perform" do
    it "runs the full pipeline and updates book status to completed" do
      # Create a real PDF that the worker will "download"
      fake_pdf = Tempfile.new(["source", ".pdf"])
      create_test_pdf(fake_pdf.path)

      allow(AliyunOssService).to receive(:new).and_return(oss_service)
      allow(oss_service).to receive(:download_file) do |object_key:, local_path:|
        FileUtils.cp(fake_pdf.path, local_path)
      end
      allow(oss_service).to receive(:upload_data).and_return("https://epub-files.oss-cn-beijing.aliyuncs.com/epub-assets/pages/#{book.id}/page_1/image_1.png")
      allow(oss_service).to receive(:upload_file) do |object_key:, **|
        "https://epub-files.oss-cn-beijing.aliyuncs.com/#{object_key}"
      end

      described_class.new.perform({
                                    book_id: book.id,
                                    pdf_oss_key: pdf_oss_key,
                                    force_image_pages: false
                                  })

      book.reload
      expect(book.epub_export_status).to eq("completed")
      expect(book.epub_oss_url).to include(".epub")
      expect(book.epub_oss_key).to eq("#{book.name}/#{book.name}.epub")
      expect(book.epub_export_error).to be_nil
      expect(book.styles_oss_url).to include("book.css")
      expect(book.nav_oss_url).to include("nav.xhtml")
      expect(book.ebook_pages.where.not(xhtml_content: nil).count).to be > 0
      expect(book.ebook_pages.first.xhtml_content).to include(book.styles_oss_url)

      fake_pdf.close!
    end

    it "sets export_failed status and records error on failure" do
      allow(AliyunOssService).to receive(:new).and_raise(AliyunOssService::UploadError, "OSS 连接失败")

      expect do
        described_class.new.perform({
                                      book_id: book.id,
                                      pdf_oss_key: pdf_oss_key,
                                      force_image_pages: false
                                    })
      end.to raise_error(AliyunOssService::UploadError)

      book.reload
      expect(book.epub_export_status).to eq("export_failed")
      expect(book.epub_export_error).to include("OSS 连接失败")
    end

    it "always re-imports the PDF in image mode, even when force_image_pages is passed as false" do
      fake_pdf = Tempfile.new(["source", ".pdf"])
      create_test_pdf(fake_pdf.path)

      allow(AliyunOssService).to receive(:new).and_return(oss_service)
      allow(oss_service).to receive(:download_file) do |object_key:, local_path:|
        FileUtils.cp(fake_pdf.path, local_path)
      end
      allow(oss_service).to receive(:upload_data).and_return("https://epub-files.oss-cn-beijing.aliyuncs.com/test.png")
      allow(oss_service).to receive(:upload_file) do |object_key:, **|
        "https://epub-files.oss-cn-beijing.aliyuncs.com/#{object_key}"
      end

      importer = instance_double(Ebook::PdfImporter, call: true)
      allow(Ebook::PdfImporter).to receive(:new).and_return(importer)

      described_class.new.perform({
                                    book_id: book.id,
                                    pdf_oss_key: pdf_oss_key,
                                    force_image_pages: false
                                  })

      expect(Ebook::PdfImporter).to have_received(:new).with(
        hash_including(force_image_pages: true)
      )

      fake_pdf.close!
    end

    it "passes force_image_pages true to the PDF importer" do
      fake_pdf = Tempfile.new(["source", ".pdf"])
      create_test_pdf(fake_pdf.path)

      allow(AliyunOssService).to receive(:new).and_return(oss_service)
      allow(oss_service).to receive(:download_file) do |object_key:, local_path:|
        FileUtils.cp(fake_pdf.path, local_path)
      end
      allow(oss_service).to receive(:upload_data).and_return("https://epub-files.oss-cn-beijing.aliyuncs.com/test.png")
      allow(oss_service).to receive(:upload_file) do |object_key:, **|
        "https://epub-files.oss-cn-beijing.aliyuncs.com/#{object_key}"
      end

      importer = instance_double(Ebook::PdfImporter, call: true)
      allow(Ebook::PdfImporter).to receive(:new).and_return(importer)

      described_class.new.perform({
                                    book_id: book.id,
                                    pdf_oss_key: pdf_oss_key,
                                    force_image_pages: true
                                  })

      expect(Ebook::PdfImporter).to have_received(:new).with(
        hash_including(force_image_pages: true)
      )

      fake_pdf.close!
    end

    it "uses book name as OSS directory name" do
      book.update!(name: "快乐先生")
      fake_pdf = Tempfile.new(["source", ".pdf"])
      create_test_pdf(fake_pdf.path)

      allow(AliyunOssService).to receive(:new).and_return(oss_service)
      allow(oss_service).to receive(:download_file) do |object_key:, local_path:|
        FileUtils.cp(fake_pdf.path, local_path)
      end
      allow(oss_service).to receive(:upload_data).and_return("https://epub-files.oss-cn-beijing.aliyuncs.com/test.png")
      allow(oss_service).to receive(:upload_file) do |object_key:, **|
        "https://epub-files.oss-cn-beijing.aliyuncs.com/#{object_key}"
      end

      described_class.new.perform({
                                    book_id: book.id,
                                    pdf_oss_key: pdf_oss_key,
                                    force_image_pages: false
                                  })

      book.reload
      expect(book.epub_oss_key).to eq("快乐先生/快乐先生.epub")
      expect(book.styles_oss_url).to include("快乐先生/styles/book.css")
      expect(book.nav_oss_url).to include("快乐先生/nav.xhtml")

      fake_pdf.close!
    end

    it "sanitizes special characters in book name for directory name" do
      book.update!(name: "Test/Book:With*Special?Chars")
      fake_pdf = Tempfile.new(["source", ".pdf"])
      create_test_pdf(fake_pdf.path)

      allow(AliyunOssService).to receive(:new).and_return(oss_service)
      allow(oss_service).to receive(:download_file) do |object_key:, local_path:|
        FileUtils.cp(fake_pdf.path, local_path)
      end
      allow(oss_service).to receive(:upload_data).and_return("https://epub-files.oss-cn-beijing.aliyuncs.com/test.png")
      allow(oss_service).to receive(:upload_file) do |object_key:, **|
        "https://epub-files.oss-cn-beijing.aliyuncs.com/#{object_key}"
      end

      described_class.new.perform({
                                    book_id: book.id,
                                    pdf_oss_key: pdf_oss_key,
                                    force_image_pages: false
                                  })

      book.reload
      sanitized = "TestBookWithSpecialChars"
      expect(book.epub_oss_key).to eq("#{sanitized}/#{sanitized}.epub")
      expect(book.styles_oss_url).to include("#{sanitized}/styles/book.css")

      fake_pdf.close!
    end
  end
end
