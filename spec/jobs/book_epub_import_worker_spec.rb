# frozen_string_literal: true

require "rails_helper"
require "zip"
require "nokogiri"

RSpec.describe BookEpubImportWorker do
  let(:book) { create(:book, status: :published, content_type: :ebook, name: "小老虎历险记") }
  let(:oss_service) { instance_double(AliyunOssService) }
  let(:epub_oss_key) { "小老虎历险记.epub" }
  let(:test_epub_path) { "/tmp/test_book_epub_import.epub" }

  before do
    create_test_epub_with_chapters(test_epub_path)
    allow(AliyunOssService).to receive(:new).and_return(oss_service)
    allow(oss_service).to receive(:download_file) do |object_key:, local_path:|
      FileUtils.cp(test_epub_path, local_path)
    end
    allow(oss_service).to receive(:upload_file) do |local_path:, object_key:, content_type: nil|
      "https://test-bucket.oss-cn-beijing.aliyuncs.com/#{object_key}"
    end
  end

  after do
    FileUtils.rm_f(test_epub_path)
  end

  def create_test_epub_with_chapters(path)
    Dir.mktmpdir("epub-book-import") do |tmp_dir|
      root = Pathname.new(tmp_dir)

      File.write(root.join("mimetype"), "application/epub+zip")

      FileUtils.mkdir_p(root.join("META-INF"))
      File.write(root.join("META-INF/container.xml"), <<~XML)
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles>
            <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
      XML

      FileUtils.mkdir_p(root.join("OEBPS/pages"))
      FileUtils.mkdir_p(root.join("OEBPS/images"))
      File.write(root.join("OEBPS/content.opf"), <<~XML)
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:identifier id="bookid">urn:uuid:test123</dc:identifier>
            <dc:title>Test Book</dc:title>
            <dc:language>zh-CN</dc:language>
          </metadata>
          <manifest>
            <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
            <item id="chapter1" href="pages/chapter1.xhtml" media-type="application/xhtml+xml"/>
            <item id="chapter2" href="pages/chapter2.xhtml" media-type="application/xhtml+xml"/>
            <item id="chapter3" href="pages/chapter3.xhtml" media-type="application/xhtml+xml"/>
            <item id="img1" href="images/cover.jpg" media-type="image/jpeg"/>
            <item id="img2" href="images/illustration.png" media-type="image/png"/>
          </manifest>
          <spine>
            <itemref idref="chapter1"/>
            <itemref idref="chapter2"/>
            <itemref idref="chapter3"/>
          </spine>
        </package>
      XML

      File.write(root.join("OEBPS/nav.xhtml"), <<~XHTML)
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml">
          <head><title>目录</title></head>
          <body>
            <nav epub:type="toc"><ol>
              <li><a href="pages/chapter1.xhtml">第一章 出发</a></li>
              <li><a href="pages/chapter2.xhtml">第二章 冒险</a></li>
              <li><a href="pages/chapter3.xhtml">第三章 回家</a></li>
            </ol></nav>
          </body>
        </html>
      XHTML

      %w[chapter1 chapter2 chapter3].each_with_index do |name, i|
        # chapter1 包含相对路径图片引用，chapter2/3 不包含
        if name == "chapter1"
          File.write(root.join("OEBPS/pages/#{name}.xhtml"), <<~XHTML)
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE html>
            <html xmlns="http://www.w3.org/1999/xhtml">
              <head><title>Page #{i + 1}</title></head>
              <body>
                <p>这是第 #{i + 1} 章的内容，测试字数统计</p>
                <img alt="cover" src="../images/cover.jpg" />
              </body>
            </html>
          XHTML
        else
          File.write(root.join("OEBPS/pages/#{name}.xhtml"), <<~XHTML)
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE html>
            <html xmlns="http://www.w3.org/1999/xhtml">
              <head><title>Page #{i + 1}</title></head>
              <body><p>这是第 #{i + 1} 章的内容，测试字数统计</p></body>
            </html>
          XHTML
        end
      end

      # 创建测试图片文件
      File.binwrite(root.join("OEBPS/images/cover.jpg"), "\xFF\xD8\xFF\xE0 fake jpeg data")
      File.binwrite(root.join("OEBPS/images/illustration.png"), "\x89PNG fake png data")

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
      dir_name = "#{prefix}#{entry.basename}/"
      zip.put_next_entry(dir_name)
      entry.each_child { |child| add_entry_to_zip(zip, child, dir_name) }
    else
      zip.put_next_entry("#{prefix}#{entry.basename}")
      zip.write(File.read(entry))
    end
  end

  def perform_import
    described_class.new.perform({
                                  "book_id" => book.id,
                                  "epub_oss_key" => epub_oss_key
                                })
    book.reload
  end

  describe "#perform" do
    it "creates ebook pages and chapters from EPUB TOC" do
      perform_import

      expect(book.ebook_pages.count).to eq(3)
      expect(book.catalogues.count).to eq(3)
      expect(book.import_status).to eq("ready")
    end

    it "creates chapters with correct chapter_number, name, and start_page" do
      perform_import

      chapters = book.catalogues.ordered
      expect(chapters[0].chapter_name).to eq("第一章 出发")
      expect(chapters[0].start_page_number).to eq(1)
      expect(chapters[1].chapter_name).to eq("第二章 冒险")
      expect(chapters[1].start_page_number).to eq(2)
      expect(chapters[2].chapter_name).to eq("第三章 回家")
      expect(chapters[2].start_page_number).to eq(3)
    end

    it "creates chapters with correct word_count for each chapter" do
      perform_import

      chapters = book.catalogues.ordered
      # 每个章节的 XHTML 内容都包含 "这是第N章的内容，测试字数统计"
      # word_count 应该是 XHTML body 中去除空白后的文字长度
      chapters.each do |chapter|
        expect(chapter.word_count).to be > 0
      end
      # 三章内容相同，字数应一致
      expect(chapters[0].word_count).to eq(chapters[1].word_count)
      expect(chapters[1].word_count).to eq(chapters[2].word_count)
    end

    it "clears existing chapters before rebuilding" do
      create(:catalogue, book: book, chapter_number: 99, chapter_name: "旧章节", start_page_number: 99)
      expect(book.catalogues.count).to eq(1)

      perform_import

      expect(book.catalogues.count).to eq(3)
      expect(book.catalogues.find_by(chapter_number: 99)).to be_nil
    end

    it "marks import as failed on error" do
      allow(AliyunOssService).to receive(:new).and_raise("OSS connection failed")

      expect {
        described_class.new.perform({
                                      "book_id" => book.id,
                                      "epub_oss_key" => epub_oss_key
                                    })
      }.to raise_error(/OSS connection failed/)

      book.reload
      expect(book.import_status).to eq("failed")
      expect(book.import_error_message).to include("OSS connection failed")
    end

    it "uploads images and replaces relative paths in XHTML with OSS URLs" do
      perform_import

      first_page = book.ebook_pages.find_by(page_number: 1)
      expect(first_page.xhtml_content).to include("https://test-bucket.oss-cn-beijing.aliyuncs.com/")
      expect(first_page.xhtml_content).to include('src="https://test-bucket.oss-cn-beijing.aliyuncs.com/')
      # 原始相对路径应被替换（不再以相对路径形式出现）
      expect(first_page.xhtml_content).not_to match(%r{src=["']?\.\./images/})
    end

    it "uploads all images from the EPUB manifest to OSS" do
      perform_import

      expect(oss_service).to have_received(:upload_file).with(
        hash_including(object_key: include("images/cover.jpg"), content_type: "image/jpeg")
      )
      expect(oss_service).to have_received(:upload_file).with(
        hash_including(object_key: include("images/illustration.png"), content_type: "image/png")
      )
    end

    it "多个 TOC 指向同一文件时 start_page_number 互不相同" do
      # 构建一个两个 TOC 条目指向同一 spine 的 EPUB
      multi_toc_epub = "/tmp/test_multi_toc_epub.epub"
      Dir.mktmpdir("epub-multi-toc") do |tmp_dir|
        root = Pathname.new(tmp_dir)

        File.write(root.join("mimetype"), "application/epub+zip")
        FileUtils.mkdir_p(root.join("META-INF"))
        File.write(root.join("META-INF/container.xml"), <<~XML)
          <?xml version="1.0" encoding="UTF-8"?>
          <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
            <rootfiles>
              <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
            </rootfiles>
          </container>
        XML

        FileUtils.mkdir_p(root.join("OEBPS/pages"))
        File.write(root.join("OEBPS/content.opf"), <<~XML)
          <?xml version="1.0" encoding="UTF-8"?>
          <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid">
            <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
              <dc:identifier id="bookid">urn:uuid:test456</dc:identifier>
              <dc:title>Multi TOC Book</dc:title>
              <dc:language>zh-CN</dc:language>
            </metadata>
            <manifest>
              <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
              <item id="shared" href="pages/shared.xhtml" media-type="application/xhtml+xml"/>
            </manifest>
            <spine>
              <itemref idref="shared"/>
            </spine>
          </package>
        XML

        File.write(root.join("OEBPS/nav.xhtml"), <<~XHTML)
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE html>
          <html xmlns="http://www.w3.org/1999/xhtml">
            <head><title>目录</title></head>
            <body>
              <nav epub:type="toc"><ol>
                <li><a href="pages/shared.xhtml">章 A</a></li>
                <li><a href="pages/shared.xhtml">章 B</a></li>
              </ol></nav>
            </body>
          </html>
        XHTML

        File.write(root.join("OEBPS/pages/shared.xhtml"), <<~XHTML)
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE html>
          <html xmlns="http://www.w3.org/1999/xhtml">
            <head><title>Shared</title></head>
            <body><p>共享内容，12 个字。</p></body>
          </html>
        XHTML

        Zip::OutputStream.open(multi_toc_epub) do |zip|
          zip.put_next_entry("mimetype", nil, nil, Zip::COMPRESSION_METHOD_STORE)
          zip.write("application/epub+zip")
          root.each_child do |entry|
            next if entry.basename.to_s == "mimetype"
            add_entry_to_zip(zip, entry, "")
          end
        end
      end

      allow(oss_service).to receive(:download_file) do |object_key:, local_path:|
        FileUtils.cp(multi_toc_epub, local_path)
      end

      perform_import

      catalogues = book.catalogues.ordered
      expect(catalogues.count).to eq(2)
      expect(catalogues[0].chapter_name).to eq("章 A")
      expect(catalogues[0].start_page_number).to eq(1)
      expect(catalogues[1].chapter_name).to eq("章 B")
      expect(catalogues[1].start_page_number).to eq(2)

      # 只有第一个 ebook_page 有字数
      pages = book.ebook_pages.order(:page_number)
      expect(pages.count).to eq(2)
      expect(pages[0].word_count).to be > 0
      expect(pages[1].word_count).to eq(0)

      FileUtils.rm_f(multi_toc_epub)
    end
  end
end
