# frozen_string_literal: true

require "rails_helper"
require "zip"
require "nokogiri"

RSpec.describe EpubImportWorker do
  let(:book) { create(:book, status: :published, content_type: :ebook, name: "小老虎历险记") }
  let(:oss_service) { instance_double(AliyunOssService) }
  let(:epub_oss_key) { "小老虎历险记.epub" }

  after do
    FileUtils.rm_rf(Rails.public_path.join("system/ebooks"))
  end

  def create_test_epub(path)
    Dir.mktmpdir("epub-build") do |tmp_dir|
      root = Pathname.new(tmp_dir)

      # mimetype
      File.write(root.join("mimetype"), "application/epub+zip")

      # container.xml
      FileUtils.mkdir_p(root.join("META-INF"))
      File.write(root.join("META-INF/container.xml"), <<~XML)
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles>
            <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
      XML

      # content.opf
      FileUtils.mkdir_p(root.join("OEBPS/pages"))
      FileUtils.mkdir_p(root.join("OEBPS/images"))
      FileUtils.mkdir_p(root.join("OEBPS/styles"))
      File.write(root.join("OEBPS/content.opf"), <<~XML)
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:identifier id="bookid">urn:uuid:test123</dc:identifier>
            <dc:title>Test EPUB Book</dc:title>
            <dc:language>zh-CN</dc:language>
          </metadata>
          <manifest>
            <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
            <item id="css" href="styles/book.css" media-type="text/css"/>
            <item id="page-1" href="pages/page-0001.xhtml" media-type="application/xhtml+xml"/>
            <item id="page-image-1" href="images/page-1.png" media-type="image/png"/>
            <item id="page-2" href="pages/page-0002.xhtml" media-type="application/xhtml+xml"/>
            <item id="page-image-2" href="images/page-2.png" media-type="image/png"/>
          </manifest>
          <spine>
            <itemref idref="page-1"/>
            <itemref idref="page-2"/>
          </spine>
        </package>
      XML

      # nav.xhtml
      File.write(root.join("OEBPS/nav.xhtml"), <<~XHTML)
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml">
          <head><title>目录</title><link rel="stylesheet" href="styles/book.css"/></head>
          <body>
            <nav epub:type="page-list"><ol>
              <li><a href="pages/page-0001.xhtml">第 1 页</a></li>
              <li><a href="pages/page-0002.xhtml">第 2 页</a></li>
            </ol></nav>
          </body>
        </html>
      XHTML

      # book.css
      File.write(root.join("OEBPS/styles/book.css"), "body { margin: 0; }")

      # page XHTML files
      File.write(root.join("OEBPS/pages/page-0001.xhtml"), <<~XHTML)
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml">
          <head><title>Page 1</title>
            <meta name="viewport" content="width=800,height=1000"/>
            <link rel="stylesheet" type="text/css" href="../styles/book.css"/>
          </head>
          <body><img src="../images/page-1.png" width="800" height="1000"/></body>
        </html>
      XHTML

      File.write(root.join("OEBPS/pages/page-0002.xhtml"), <<~XHTML)
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml">
          <head><title>Page 2</title>
            <meta name="viewport" content="width=800,height=1000"/>
            <link rel="stylesheet" type="text/css" href="../styles/book.css"/>
          </head>
          <body><img src="../images/page-2.png" width="800" height="1000"/></body>
        </html>
      XHTML

      # fake PNG images
      File.binwrite(root.join("OEBPS/images/page-1.png"), "\x89PNG\r\n\x1a\n" + ("fake data" * 10))
      File.binwrite(root.join("OEBPS/images/page-2.png"), "\x89PNG\r\n\x1a\n" + ("fake data" * 10))

      # zip it
      Zip::OutputStream.open(path) do |zip|
        zip.put_next_entry("mimetype", nil, nil, Zip::COMPRESSION_METHOD_STORE)
        zip.write("application/epub+zip")
        root.each_child do |entry|
          next if entry.basename.to_s == "mimetype"

          add_entry_to_zip(zip, entry, "")
        end
      end
    end
  end

  def add_entry_to_zip(zip, entry, prefix)
    if entry.directory?
      entry.each_child { |child| add_entry_to_zip(zip, child, "#{prefix}#{entry.basename}/") }
    else
      zip.put_next_entry("#{prefix}#{entry.basename}")
      zip.write(File.read(entry))
    end
  end

  describe "#perform" do
    it "runs the full EPUB import pipeline and updates book status" do
      # Use the real test EPUB file
      real_epub = Pathname.new("/tmp/test.epub")
      skip "Test EPUB not found. Download with: curl -sL URL -o /tmp/test.epub" unless real_epub.exist?

      allow(AliyunOssService).to receive(:new).and_return(oss_service)
      allow(oss_service).to receive(:download_file) do |object_key:, local_path:|
        FileUtils.cp(real_epub, local_path)
      end
      allow(oss_service).to receive(:upload_file) do |object_key:, **|
        "https://epub-files.oss-cn-beijing.aliyuncs.com/#{object_key}"
      end

      described_class.new.perform({
                                    book_id: book.id,
                                    epub_oss_key: epub_oss_key
                                  })

      book.reload
      expect(book.epub_export_status).to eq("completed")
      expect(book.epub_oss_url).to include(".epub")
      expect(book.epub_oss_key).to include(book.name)
      expect(book.epub_export_error).to be_nil
      expect(book.styles_oss_url).to include("styles/book.css")
      expect(book.nav_oss_url).to include("nav.xhtml")
      expect(book.ebook_pages.count).to be > 0

      # Check page XHTML has OSS URLs
      first_page = book.ebook_pages.first
      expect(first_page.xhtml_content).to include("https://epub-files.oss-cn-beijing.aliyuncs.com/")
      expect(first_page.xhtml_content).to include(book.styles_oss_url)

      # Check page dimensions from viewport
      expect(first_page.page_width).to be > 0
      expect(first_page.page_height).to be > 0
    end

    it "clears existing pages before rebuilding" do
      real_epub = Pathname.new("/tmp/test.epub")
      skip "Test EPUB not found" unless real_epub.exist?

      create(:ebook_page, book: book, page_number: 999, page_width: 100, page_height: 100, plain_text: "old page")
      expect(book.ebook_pages.count).to eq(1)

      allow(AliyunOssService).to receive(:new).and_return(oss_service)
      allow(oss_service).to receive(:download_file) do |object_key:, local_path:|
        FileUtils.cp(real_epub, local_path)
      end
      allow(oss_service).to receive(:upload_file) do |object_key:, **|
        "https://epub-files.oss-cn-beijing.aliyuncs.com/#{object_key}"
      end

      described_class.new.perform({
                                    book_id: book.id,
                                    epub_oss_key: epub_oss_key
                                  })

      book.reload
      expect(book.ebook_pages.where(page_number: 999).count).to eq(0)
      expect(book.ebook_pages.count).to be > 0
    end

    it "sets export_failed status and records error on failure" do
      allow(AliyunOssService).to receive(:new).and_raise(AliyunOssService::UploadError, "OSS 连接失败")

      expect do
        described_class.new.perform({
                                      book_id: book.id,
                                      epub_oss_key: epub_oss_key
                                    })
      end.to raise_error(AliyunOssService::UploadError)

      book.reload
      expect(book.epub_export_status).to eq("export_failed")
      expect(book.epub_export_error).to include("OSS 连接失败")
    end

    it "uses book name as OSS directory name" do
      real_epub = Pathname.new("/tmp/test.epub")
      skip "Test EPUB not found" unless real_epub.exist?

      book.update!(name: "快乐先生")

      allow(AliyunOssService).to receive(:new).and_return(oss_service)
      allow(oss_service).to receive(:download_file) do |object_key:, local_path:|
        FileUtils.cp(real_epub, local_path)
      end
      allow(oss_service).to receive(:upload_file) do |object_key:, **|
        "https://epub-files.oss-cn-beijing.aliyuncs.com/#{object_key}"
      end

      described_class.new.perform({
                                    book_id: book.id,
                                    epub_oss_key: epub_oss_key
                                  })

      book.reload
      expect(book.epub_oss_key).to eq("快乐先生/快乐先生.epub")
      expect(book.styles_oss_url).to include("快乐先生/styles/book.css")
    end
  end
end
