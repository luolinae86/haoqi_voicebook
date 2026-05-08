# frozen_string_literal: true

require "base64"
require "rails_helper"
require "zip"

RSpec.describe Ebook::LocalExportWorker do
  let(:files) { create_sample_ebook_pdf }
  let(:output_dir) { Rails.root.join("tmp/spec_ebook_worker_output") }

  after do
    cleanup_sample_ebook_pdf(files)
    FileUtils.rm_rf(output_dir)
    FileUtils.rm_rf(Rails.public_path.join("system/ebooks"))
  end

  it "imports a pdf and exports text plus image assets to the target directory" do
    described_class.new(
      pdf_path: files[:pdf].path,
      output_dir: output_dir,
      title: "Worker Export Book",
      source_filename: "worker-export.pdf"
    ).call

    manifest = JSON.parse(File.read(output_dir.join("manifest.json")))
    page_one = JSON.parse(File.read(output_dir.join("pages/page-0001.json")))
    epub_path = output_dir.join("Worker Export Book.epub")

    expect(manifest.dig("book", "title")).to eq("Worker Export Book")
    expect(manifest.dig("book", "source_pdf_path")).to eq(files[:pdf].path)
    expect(manifest["directories"]).not_to be_empty
    expect(page_one["text"]).to include("[TITLE] Chapter 1 Luminous Badge\n")
    expect(page_one.dig("directory", "title")).to eq("Chapter 1 Luminous Badge")
    expect(page_one.dig("lines", 0, "style", "font_family")).to be_present
    expect(page_one["images"].size).to eq(1)
    expect(Dir.glob(output_dir.join("assets/*").to_s)).not_to be_empty
    expect(epub_path).to exist

    Zip::File.open(epub_path.to_s) do |zip|
      expect(zip.find_entry("mimetype")).to be_present
      expect(zip.find_entry("OEBPS/nav.xhtml")).to be_present
      expect(zip.find_entry("OEBPS/content.opf")).to be_present
      expect(zip.find_entry("OEBPS/pages/page-0001.xhtml")).to be_present
    end
  end

  it "passes force_image_pages through to the importer" do
    book = create(:book, title: "Worker Export Book", status: :published, content_type: :ebook)
    importer = instance_double(Ebook::PdfImporter, call: true)
    exporter = instance_double(Ebook::ExportPackage, call: output_dir)
    epub_exporter = instance_double(Ebook::EpubExporter, call: output_dir.join("Worker Export Book.epub"))

    allow(Ebook::PdfImporter).to receive(:new).and_return(importer)
    allow(Ebook::ExportPackage).to receive(:new).and_return(exporter)
    allow(Ebook::EpubExporter).to receive(:new).and_return(epub_exporter)
    allow(book).to receive(:reload).and_return(book)
    allow(book).to receive_messages(page_count: 2, title: "Worker Export Book")

    described_class.new(
      pdf_path: files[:pdf].path,
      output_dir: output_dir,
      title: "Worker Export Book",
      book: book,
      source_filename: "worker-export.pdf",
      force_image_pages: true
    ).call

    expect(Ebook::PdfImporter).to have_received(:new).with(
      hash_including(
        book: book,
        pdf_path: Pathname.new(files[:pdf].path),
        source_filename: "worker-export.pdf",
        force_image_pages: true
      )
    )
  end

  it "builds epub from the exported package files" do
    described_class.new(
      pdf_path: files[:pdf].path,
      output_dir: output_dir,
      title: "Worker Export Book",
      source_filename: "worker-export.pdf"
    ).call

    page_file = output_dir.join("pages/page-0002.json")
    payload = JSON.parse(File.read(page_file))
    payload["text"] = "[TITLE] Package Driven EPUB\n[BODY] Exported from pages JSON only.\n"
    payload["lines"] = []
    File.write(page_file, JSON.pretty_generate(payload))

    epub_path = output_dir.join("package-driven.epub")
    Ebook::EpubExporter.new(package_dir: output_dir, output_path: epub_path).call

    Zip::File.open(epub_path.to_s) do |zip|
      page_text = zip.entries
                     .select { |entry| entry.name.start_with?("OEBPS/pages/page-") }
                     .map { |entry| zip.read(entry.name) }
                     .join("\n")
      expect(page_text).to include("Package Driven EPUB")
      expect(page_text).to include("Exported from pages JSON only.")
    end
  end

  it "keeps full-page image books at the original viewport width and disables spread mode" do
    described_class.new(
      pdf_path: files[:pdf].path,
      output_dir: output_dir,
      title: "Worker Export Book",
      source_filename: "worker-export.pdf"
    ).call

    %w[page-0001.json page-0002.json].each do |filename|
      page_file = output_dir.join("pages", filename)
      payload = JSON.parse(File.read(page_file))
      source_image = payload.fetch("images", []).first || JSON.parse(File.read(output_dir.join("pages/page-0001.json"))).fetch("images").first
      payload["text"] = ""
      payload["lines"] = []
      payload["page_width"] = "428.03"
      payload["page_height"] = "612.28"
      payload["images"] = [
        source_image.merge(
          "bbox" => {
            "left" => 0.0,
            "bottom" => 0.0,
            "width" => 428.03,
            "height" => 612.28,
            "right" => 428.03,
            "top" => 612.28
          },
          "source_filter" => "QuartzPageRender"
        )
      ]
      File.write(page_file, JSON.pretty_generate(payload))
    end

    epub_path = output_dir.join("full-page-images.epub")
    Ebook::EpubExporter.new(package_dir: output_dir, output_path: epub_path).call

    Zip::File.open(epub_path.to_s) do |zip|
      page_xhtml = zip.read("OEBPS/pages/page-0001.xhtml")
      content_opf = zip.read("OEBPS/content.opf")

      # For full-page image books, viewport matches the image pixel dimensions
      # (image is rendered at 2× scale, so viewport = image_width × image_height)
      # Test image is ~856×1224 pixels, so viewport should be close to that
      expect(page_xhtml).to include("<style type=\"text/css\">")
      expect(page_xhtml).to include("overflow:hidden")
      expect(page_xhtml).to include('class="page-full-image"')
      expect(page_xhtml).to include('src="../images/')
      expect(page_xhtml).to include("width=")
      expect(page_xhtml).not_to include("<svg")
      expect(content_opf).to include('<meta property="rendition:spread">none</meta>')
    end
  end

  it "renders chapter headings from cropped pdf title images when a page renderer is available" do
    described_class.new(
      pdf_path: files[:pdf].path,
      output_dir: output_dir,
      title: "Worker Export Book",
      source_filename: "worker-export.pdf"
    ).call

    page_file = output_dir.join("pages/page-0002.json")
    payload = JSON.parse(File.read(page_file))
    payload["page_width"] = "428.03"
    payload["page_height"] = "220"
    payload["images"] = []
    payload["lines"] = [
      {
        "id" => "line-1",
        "bbox" => { "top" => 175.0, "left" => 72.05, "right" => 204.3, "width" => 132.25, "bottom" => 145.0, "height" => 30.0 },
        "role" => "heading",
        "text" => "发光的徽章",
        "style" => { "align" => "left", "font_family" => "HYp1gj", "font_size_pt" => 30.0 }
      }
    ]
    File.write(page_file, JSON.pretty_generate(payload))

    tiny_png = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+yX1cAAAAASUVORK5CYII=")
    renderer = instance_double(Ebook::PageImageRenderer, available?: true, close: nil)
    allow(renderer).to receive(:render_crop).and_return(
      {
        bytes: tiny_png,
        extension: "png",
        mime_type: "image/png",
        image_width: 10,
        image_height: 10,
        filter: "QuartzPageRender"
      }
    )

    epub_path = output_dir.join("title-image.epub")
    Ebook::EpubExporter.new(
      package_dir: output_dir,
      output_path: epub_path,
      source_pdf_path: files[:pdf].path,
      page_renderer: renderer
    ).call

    Zip::File.open(epub_path.to_s) do |zip|
      page_xhtml = zip.read("OEBPS/pages/page-0002.xhtml").force_encoding("UTF-8")

      expect(page_xhtml).to include('class="page-title-image"')
      expect(page_xhtml).not_to include(%(class="page-text-layer page-heading"))
      expect(zip.find_entry("OEBPS/images/title-2-1.png")).to be_present
    end
  end

  it "keeps full-page rendered image pages as image-only epub pages" do
    described_class.new(
      pdf_path: files[:pdf].path,
      output_dir: output_dir,
      title: "Worker Export Book",
      source_filename: "worker-export.pdf"
    ).call

    page_file = output_dir.join("pages/page-0002.json")
    payload = JSON.parse(File.read(page_file))
    payload["page_width"] = "428.03"
    payload["page_height"] = "220.0"
    payload["text"] = ""
    payload["lines"] = []
    payload["images"] = [
      {
        "id" => "image-2-1",
        "bbox" => {
          "top" => 220.0,
          "left" => 0.0,
          "right" => 428.03,
          "width" => 428.03,
          "bottom" => 0.0,
          "height" => 220.0
        },
        "role" => "hero_image",
        "type" => "image",
        "image_url" => "/system/ebooks/book_1/page_2/image_1.png",
        "mime_type" => "image/png",
        "source_filter" => Ebook::PageImageRenderer::PDFTOCAIRO_FILTER
      }
    ]
    File.write(page_file, JSON.pretty_generate(payload))

    source_asset = Dir[output_dir.join("assets/*").to_s].first
    FileUtils.cp(source_asset, output_dir.join("assets/2-image_1#{File.extname(source_asset)}")) if source_asset

    epub_path = output_dir.join("image-only-page.epub")
    Ebook::EpubExporter.new(package_dir: output_dir, output_path: epub_path).call

    Zip::File.open(epub_path.to_s) do |zip|
      page_xhtml = zip.read("OEBPS/pages/page-0002.xhtml").force_encoding("UTF-8")

      expect(page_xhtml).to include('class="page-content-frame" style="padding: 0 0.0px; position: relative;')
      expect(page_xhtml).to include("<style type=\"text/css\">")
      expect(page_xhtml).to include("overflow:hidden")
      expect(page_xhtml).to include('class="page-full-image"')
      expect(page_xhtml).not_to include('class="page-text-layer')
      expect(page_xhtml).not_to include("<svg")
    end
  end

  it "embeds extracted pdf fonts into epub and binds text layers to them" do
    described_class.new(
      pdf_path: files[:pdf].path,
      output_dir: output_dir,
      title: "Worker Export Book",
      source_filename: "worker-export.pdf"
    ).call

    page_file = output_dir.join("pages/page-0002.json")
    payload = JSON.parse(File.read(page_file))
    payload["page_width"] = "428.03"
    payload["page_height"] = "220"
    payload["images"] = []
    payload["lines"] = [
      {
        "id" => "line-1",
        "bbox" => { "top" => 160.0, "left" => 91.56, "right" => 417.69, "width" => 326.13, "bottom" => 148.0, "height" => 12.0 },
        "role" => "body",
        "text" => "字体嵌入测试",
        "style" => {
          "align" => "left",
          "font_name" => "ABCDEF+FZSSK--GBK1-0",
          "font_family" => "FZSSK--GBK1-0",
          "font_size_pt" => 12.0
        }
      }
    ]
    File.write(page_file, JSON.pretty_generate(payload))

    extractor = instance_double(Ebook::PdfFontExtractor)
    allow(extractor).to receive(:call).and_return(
      [
        {
          source_name: "ABCDEF+FZSSK--GBK1-0",
          normalized_name: "FZSSK--GBK1-0",
          css_family: "PDFEmbed-FZSSK--GBK1-0-12345678",
          filename: "font-test.ttf",
          media_type: "font/ttf",
          format: "truetype",
          data: "TTF-DATA",
          aliases: ["ABCDEF+FZSSK--GBK1-0", "FZSSK--GBK1-0"]
        }
      ]
    )

    epub_path = output_dir.join("embedded-font.epub")
    Ebook::EpubExporter.new(
      package_dir: output_dir,
      output_path: epub_path,
      font_extractor: extractor
    ).call

    expect(extractor).to have_received(:call).with(
      hash_including(
        used_font_names: include("ABCDEF+FZSSK--GBK1-0"),
        used_font_families: include("FZSSK--GBK1-0")
      )
    )

    Zip::File.open(epub_path.to_s) do |zip|
      css = zip.read("OEBPS/styles/book.css").force_encoding("UTF-8")
      page_xhtml = zip.read("OEBPS/pages/page-0002.xhtml").force_encoding("UTF-8")
      font_payload = zip.read("OEBPS/fonts/font-test.ttf")
      opf = zip.read("OEBPS/content.opf").force_encoding("UTF-8")

      expect(font_payload).to eq("TTF-DATA")
      expect(css).to include("@font-face")
      expect(css).to include("font-family: 'PDFEmbed-FZSSK--GBK1-0-12345678'")
      expect(css).to include("src: url('../fonts/font-test.ttf') format('truetype')")
      expect(page_xhtml).to include('meta name="viewport" content="width=492.03,height=220.0"')
      expect(page_xhtml).to include('class="page-content-frame" style="padding: 0 32.0px; position: relative;')
      expect(page_xhtml).to include("font-size: 12.0px")
      expect(page_xhtml).to include("left: 91.56px; top: 60.0px; width: 326.13px;")
      expect(page_xhtml).to include("font-family: 'PDFEmbed-FZSSK--GBK1-0-12345678', 'FZSSK--GBK1-0', 'ABCDEF+FZSSK--GBK1-0', sans-serif")
      expect(opf).to include('href="fonts/font-test.ttf" media-type="font/ttf"')
    end
  end

  it "keeps lines on one row and strips side-image text noise in fixed-layout epub" do
    described_class.new(
      pdf_path: files[:pdf].path,
      output_dir: output_dir,
      title: "Worker Export Book",
      source_filename: "worker-export.pdf"
    ).call

    page_file = output_dir.join("pages/page-0002.json")
    payload = JSON.parse(File.read(page_file))
    payload["page_width"] = "428.03"
    payload["page_height"] = "220"
    payload["images"] = [
      {
        "id" => "image-2-1",
        "bbox" => {
          "top" => 210.0,
          "left" => 70.0,
          "right" => 130.0,
          "width" => 60.0,
          "bottom" => 180.0,
          "height" => 30.0
        },
        "role" => "hero_image",
        "type" => "image",
        "image_url" => "/system/ebooks/book_1/page_2/image_1.png",
        "mime_type" => "image/png"
      }
    ]
    payload["lines"] = [
      {
        "id" => "line-1",
        "bbox" => { "top" => 205.0, "left" => 75.0, "right" => 125.0, "width" => 50.0, "bottom" => 200.0, "height" => 5.0 },
        "role" => "body",
        "text" => "LogoText",
        "style" => { "align" => "center", "font_family" => "FZY1K--GBK1-0", "font_size_pt" => 5.5 }
      },
      {
        "id" => "line-2",
        "bbox" => { "top" => 160.0, "left" => 31.0, "right" => 36.0, "width" => 5.0, "bottom" => 151.5, "height" => 8.5 },
        "role" => "body",
        "text" => "Z",
        "style" => { "align" => "left", "font_family" => "NEU-FZ-Regular", "font_size_pt" => 8.5 }
      },
      {
        "id" => "line-3",
        "bbox" => { "top" => 149.0, "left" => 31.0, "right" => 36.0, "width" => 5.0, "bottom" => 140.5, "height" => 8.5 },
        "role" => "body",
        "text" => "U",
        "style" => { "align" => "left", "font_family" => "NEU-FZ-Regular", "font_size_pt" => 8.5 }
      },
      {
        "id" => "line-4",
        "bbox" => { "top" => 138.0, "left" => 31.0, "right" => 36.0, "width" => 5.0, "bottom" => 129.5, "height" => 8.5 },
        "role" => "body",
        "text" => "A",
        "style" => { "align" => "left", "font_family" => "NEU-FZ-Regular", "font_size_pt" => 8.5 }
      },
      {
        "id" => "line-5",
        "bbox" => { "top" => 127.0, "left" => 31.0, "right" => 37.0, "width" => 6.0, "bottom" => 118.5, "height" => 8.5 },
        "role" => "body",
        "text" => "G",
        "style" => { "align" => "left", "font_family" => "NEU-FZ-Regular", "font_size_pt" => 8.5 }
      },
      {
        "id" => "line-5b",
        "bbox" => { "top" => 121.0, "left" => 31.0, "right" => 120.0, "width" => 89.0, "bottom" => 109.5, "height" => 11.5 },
        "role" => "body",
        "text" => "IK……",
        "style" => { "align" => "left", "font_family" => "FZSSK--GBK1-0", "font_size_pt" => 11.5 }
      },
      {
        "id" => "line-6",
        "bbox" => { "top" => 116.0, "left" => 31.0, "right" => 120.0, "width" => 89.0, "bottom" => 104.5, "height" => 11.5 },
        "role" => "body",
        "text" => "H般动听。",
        "style" => { "align" => "left", "font_family" => "FZSSK--GBK1-0", "font_size_pt" => 11.5 }
      },
      {
        "id" => "line-7",
        "bbox" => { "top" => 96.0, "left" => 60.0, "right" => 140.49, "width" => 80.49, "bottom" => 84.5, "height" => 11.5 },
        "role" => "body",
        "text" => "“杨歌，小心！”",
        "style" => { "align" => "left", "font_family" => "FZSSK--GBK1-0", "font_size_pt" => 11.5 }
      }
    ]
    File.write(page_file, JSON.pretty_generate(payload))

    epub_path = output_dir.join("noise-filter.epub")
    Ebook::EpubExporter.new(package_dir: output_dir, output_path: epub_path).call

    Zip::File.open(epub_path.to_s) do |zip|
      css = zip.read("OEBPS/styles/book.css").force_encoding("UTF-8")
      page_xhtml = zip.read("OEBPS/pages/page-0002.xhtml").force_encoding("UTF-8")

      expect(css).to include("white-space: nowrap;")
      expect(css).to include("body.fixed-layout-page {")
      expect(css).to include(".page-canvas {")
      expect(css).to include("body.fixed-layout-page {\n  width: 100%;\n  height: 100%;\n  overflow: visible;")
      expect(css).to include(".page-canvas {\n  position: relative;\n  overflow: visible;")
      expect(css).to include("overflow: visible;")
      expect(page_xhtml).not_to include("LogoText")
      expect(page_xhtml).not_to include(">Z<")
      expect(page_xhtml).not_to include(">U<")
      expect(page_xhtml).not_to include(">A<")
      expect(page_xhtml).not_to include(">G<")
      expect(page_xhtml).not_to include("IK……")
      expect(page_xhtml).not_to include("H般动听。")
      expect(page_xhtml).to include("般动听。")
      expect(page_xhtml).to include("“杨歌，小心！”")
    end
  end

  it "repairs polluted line indent and alignment from nearby clean anchors" do
    described_class.new(
      pdf_path: files[:pdf].path,
      output_dir: output_dir,
      title: "Worker Export Book",
      source_filename: "worker-export.pdf"
    ).call

    page_file = output_dir.join("pages/page-0002.json")
    payload = JSON.parse(File.read(page_file))
    payload["page_width"] = "428.03"
    payload["page_height"] = "220"
    payload["images"] = []
    payload["lines"] = [
      {
        "id" => "line-1",
        "bbox" => { "top" => 190.0, "left" => 79.37, "right" => 160.0, "width" => 80.63, "bottom" => 178.5, "height" => 11.5 },
        "role" => "body",
        "text" => "上一行还没结束",
        "style" => { "align" => "center", "font_family" => "FZSSK--GBK1-0", "font_size_pt" => 11.5 }
      },
      {
        "id" => "line-2",
        "bbox" => { "top" => 168.0, "left" => 79.37, "right" => 190.0, "width" => 110.63, "bottom" => 156.5, "height" => 11.5 },
        "role" => "body",
        "text" => "正常基准行。",
        "style" => { "align" => "center", "font_family" => "FZSSK--GBK1-0", "font_size_pt" => 11.5 }
      },
      {
        "id" => "line-3",
        "bbox" => { "top" => 146.0, "left" => 102.9, "right" => 190.0, "width" => 87.1, "bottom" => 134.5, "height" => 11.5 },
        "role" => "body",
        "text" => "正常首行缩进",
        "style" => { "align" => "left", "font_family" => "FZSSK--GBK1-0", "font_size_pt" => 11.5 }
      },
      {
        "id" => "line-4",
        "bbox" => { "top" => 124.0, "left" => 31.03, "right" => 190.0, "width" => 158.97, "bottom" => 112.5, "height" => 11.5 },
        "role" => "body",
        "text" => "H所有人都回过头来看向我。",
        "style" => { "align" => "left", "font_family" => "FZSSK--GBK1-0", "font_size_pt" => 11.5 }
      },
      {
        "id" => "line-5",
        "bbox" => { "top" => 102.0, "left" => 31.03, "right" => 190.0, "width" => 158.97, "bottom" => 90.5, "height" => 11.5 },
        "role" => "body",
        "text" => "N“杨歌，你怎么啦？”班主任皱着眉头，问道。",
        "style" => { "align" => "left", "font_family" => "FZSSK--GBK1-0", "font_size_pt" => 11.5 }
      }
    ]
    File.write(page_file, JSON.pretty_generate(payload))

    epub_path = output_dir.join("indent-repair.epub")
    Ebook::EpubExporter.new(package_dir: output_dir, output_path: epub_path).call

    Zip::File.open(epub_path.to_s) do |zip|
      page_xhtml = zip.read("OEBPS/pages/page-0002.xhtml").force_encoding("UTF-8")

      expect(page_xhtml).to include(">所有人都回过头来看向我。</p>")
      expect(page_xhtml).to include(">“杨歌，你怎么啦？”班主任皱着眉头，问道。</p>")
      expect(page_xhtml).to include("left: 79.37px; top: 96.0px; width: 110.63px; min-height: 11.5px; text-align: center;")
      expect(page_xhtml).to include("left: 102.9px; top: 118.0px; width: 87.1px; min-height: 11.5px; text-align: left;")
      expect(page_xhtml).not_to include("H所有人都回过头来看向我。")
      expect(page_xhtml).not_to include("N“杨歌，你怎么啦？”")
    end
  end

  it "repairs left anchor drift caused by standalone side-noise lines" do
    described_class.new(
      pdf_path: files[:pdf].path,
      output_dir: output_dir,
      title: "Worker Export Book",
      source_filename: "worker-export.pdf"
    ).call

    page_file = output_dir.join("pages/page-0002.json")
    payload = JSON.parse(File.read(page_file))
    payload["page_width"] = "428.03"
    payload["page_height"] = "220"
    payload["images"] = []
    payload["lines"] = [
      {
        "id" => "line-1",
        "bbox" => { "top" => 190.0, "left" => 79.37, "right" => 360.0, "width" => 280.63, "bottom" => 178.5, "height" => 11.5 },
        "role" => "body",
        "text" => "就变成了一个拇指小人儿，整天待在我的口袋里，当我的",
        "style" => { "align" => "center", "font_family" => "FZSSK--GBK1-0", "font_size_pt" => 11.5 }
      },
      {
        "id" => "line-2",
        "bbox" => { "top" => 168.0, "left" => 31.03, "right" => 36.22, "width" => 5.18, "bottom" => 159.5, "height" => 8.5 },
        "role" => "body",
        "text" => "Z",
        "style" => { "align" => "left", "font_family" => "NEU-FZ-Regular", "font_size_pt" => 8.5 }
      },
      {
        "id" => "line-3",
        "bbox" => { "top" => 165.81, "left" => 31.03, "right" => 359.99, "width" => 328.96, "bottom" => 154.31, "height" => 11.5 },
        "role" => "body",
        "text" => "“教育部长”，随时随地监视我的一举一动，成了名副其实",
        "style" => { "align" => "left", "font_family" => "FZSSK--GBK1-0", "font_size_pt" => 11.5 }
      },
      {
        "id" => "line-4",
        "bbox" => { "top" => 156.69, "left" => 31.03, "right" => 37.16, "width" => 6.13, "bottom" => 148.19, "height" => 8.5 },
        "role" => "body",
        "text" => "U",
        "style" => { "align" => "left", "font_family" => "NEU-FZ-Regular", "font_size_pt" => 8.5 }
      },
      {
        "id" => "line-5",
        "bbox" => { "top" => 143.99, "left" => 31.03, "right" => 205.89, "width" => 174.86, "bottom" => 132.49, "height" => 11.5 },
        "role" => "body",
        "text" => "的“装在口袋里的爸爸”。",
        "style" => { "align" => "left", "font_family" => "FZSSK--GBK1-0", "font_size_pt" => 11.5 }
      },
      {
        "id" => "line-6",
        "bbox" => { "top" => 138.77, "left" => 31.03, "right" => 37.64, "width" => 6.6, "bottom" => 130.27, "height" => 8.5 },
        "role" => "body",
        "text" => "G",
        "style" => { "align" => "left", "font_family" => "NEU-FZ-Regular", "font_size_pt" => 8.5 }
      },
      {
        "id" => "line-7",
        "bbox" => { "top" => 132.16, "left" => 31.03, "right" => 359.99, "width" => 328.96, "bottom" => 120.66, "height" => 11.5 },
        "role" => "body",
        "text" => "至于徽章的事情，还得从我昨天上午参观市博物馆",
        "style" => { "align" => "left", "font_family" => "FZSSK--GBK1-0", "font_size_pt" => 11.5 }
      },
      {
        "id" => "line-8",
        "bbox" => { "top" => 110.0, "left" => 102.9, "right" => 190.0, "width" => 87.1, "bottom" => 98.5, "height" => 11.5 },
        "role" => "body",
        "text" => "好吧，先给故事按下暂停键。",
        "style" => { "align" => "left", "font_family" => "FZSSK--GBK1-0", "font_size_pt" => 11.5 }
      }
    ]
    File.write(page_file, JSON.pretty_generate(payload))

    epub_path = output_dir.join("side-noise-anchor.epub")
    Ebook::EpubExporter.new(package_dir: output_dir, output_path: epub_path).call

    Zip::File.open(epub_path.to_s) do |zip|
      page_xhtml = zip.read("OEBPS/pages/page-0002.xhtml").force_encoding("UTF-8")

      expect(page_xhtml).not_to include(">Z<")
      expect(page_xhtml).not_to include(">U<")
      expect(page_xhtml).not_to include(">G<")
      expect(page_xhtml).to include("left: 79.37px; top: 54.19px; width: 280.62px; min-height: 11.5px; text-align: center;")
      expect(page_xhtml).to include("left: 79.37px; top: 76.01px; width: 126.52px; min-height: 11.5px; text-align: center;")
      expect(page_xhtml).to include("left: 102.9px; top: 87.84px; width: 257.09px; min-height: 11.5px; text-align: left;")
    end
  end

  it "ignores abnormally large indent anchors when repairing polluted lines" do
    described_class.new(
      pdf_path: files[:pdf].path,
      output_dir: output_dir,
      title: "Worker Export Book",
      source_filename: "worker-export.pdf"
    ).call

    page_file = output_dir.join("pages/page-0002.json")
    payload = JSON.parse(File.read(page_file))
    payload["page_width"] = "428.03"
    payload["page_height"] = "220"
    payload["images"] = []
    payload["lines"] = [
      {
        "id" => "line-1",
        "bbox" => { "top" => 190.0, "left" => 102.9, "right" => 320.26, "width" => 217.36, "bottom" => 178.5, "height" => 11.5 },
        "role" => "body",
        "text" => "“火都烧成这样了，消防车怎么还不来？”",
        "style" => { "align" => "left", "font_family" => "FZSSK--GBK1-0", "font_size_pt" => 11.5 }
      },
      {
        "id" => "line-2",
        "bbox" => { "top" => 168.0, "left" => 211.18, "right" => 320.26, "width" => 109.08, "bottom" => 156.5, "height" => 11.5 },
        "role" => "body",
        "text" => "“听说楼上困了好些人，真是急死人了！”",
        "style" => { "align" => "center", "font_family" => "FZSSK--GBK1-0", "font_size_pt" => 11.5 }
      },
      {
        "id" => "line-3",
        "bbox" => { "top" => 146.0, "left" => 31.03, "right" => 360.0, "width" => 328.97, "bottom" => 134.5, "height" => 11.5 },
        "role" => "body",
        "text" => "D“现在是下班高峰期，这条路太堵了，消防车又不",
        "style" => { "align" => "left", "font_family" => "FZSSK--GBK1-0", "font_size_pt" => 11.5 }
      }
    ]
    File.write(page_file, JSON.pretty_generate(payload))

    epub_path = output_dir.join("anchor-guard.epub")
    Ebook::EpubExporter.new(package_dir: output_dir, output_path: epub_path).call

    Zip::File.open(epub_path.to_s) do |zip|
      page_xhtml = zip.read("OEBPS/pages/page-0002.xhtml").force_encoding("UTF-8")

      expect(page_xhtml).to include("“现在是下班高峰期，这条路太堵了，消防车又不")
      expect(page_xhtml).to include("left: 102.9px; top: 74.0px;")
      expect(page_xhtml).not_to include("left: 211.18px; top: 74.0px;")
    end
  end

  it "strips right-side chapter title fragments and clamps overflowing lines" do
    described_class.new(
      pdf_path: files[:pdf].path,
      output_dir: output_dir,
      title: "Worker Export Book",
      source_filename: "worker-export.pdf"
    ).call

    page_file = output_dir.join("pages/page-0002.json")
    payload = JSON.parse(File.read(page_file))
    payload["page_width"] = "428.03"
    payload["page_height"] = "220"
    payload["images"] = []
    payload["directory"] = { "title" => "六 自古英雄出少年" }
    payload["lines"] = [
      {
        "id" => "line-1",
        "bbox" => { "top" => 190.0, "left" => 68.03, "right" => 160.0, "width" => 91.97, "bottom" => 178.5, "height" => 11.5 },
        "role" => "body",
        "text" => "正常正文第一行。",
        "style" => { "align" => "center", "font_family" => "FZSSK--GBK1-0", "font_size_pt" => 11.5 }
      },
      {
        "id" => "line-2",
        "bbox" => { "top" => 168.0, "left" => 68.03, "right" => 160.0, "width" => 91.97, "bottom" => 156.5, "height" => 11.5 },
        "role" => "body",
        "text" => "正常正文第二行。",
        "style" => { "align" => "center", "font_family" => "FZSSK--GBK1-0", "font_size_pt" => 11.5 }
      },
      {
        "id" => "line-3",
        "bbox" => { "top" => 146.0, "left" => 68.03, "right" => 429.68, "width" => 361.65, "bottom" => 134.0, "height" => 12.0 },
        "role" => "body",
        "text" => "设计了十二种动物，也就是十二生肖，让它们来与十二地六自古英",
        "style" => { "align" => "left", "font_family" => "FZSSK--GBK1-0", "font_size_pt" => 12.0 }
      }
    ]
    File.write(page_file, JSON.pretty_generate(payload))

    epub_path = output_dir.join("right-overflow.epub")
    Ebook::EpubExporter.new(package_dir: output_dir, output_path: epub_path).call

    Zip::File.open(epub_path.to_s) do |zip|
      page_xhtml = zip.read("OEBPS/pages/page-0002.xhtml").force_encoding("UTF-8")

      expect(page_xhtml).to include("设计了十二种动物，也就是十二生肖，让它们来与十二地</p>")
      expect(page_xhtml).not_to include("六自古英")
      expect(page_xhtml).not_to include("width: 361.65px")
      expect(page_xhtml).to include("left: 68.03px; top: 74.0px;")
    end
  end

  it "strips irregular reordered title fragments from overflowing lines" do
    described_class.new(
      pdf_path: files[:pdf].path,
      output_dir: output_dir,
      title: "Worker Export Book",
      source_filename: "worker-export.pdf"
    ).call

    page_file = output_dir.join("pages/page-0002.json")
    payload = JSON.parse(File.read(page_file))
    payload["page_width"] = "428.03"
    payload["page_height"] = "220"
    payload["images"] = []
    payload["directory"] = { "title" => "二十六 尾声" }
    payload["lines"] = [
      {
        "id" => "line-1",
        "bbox" => { "top" => 190.0, "left" => 68.03, "right" => 160.0, "width" => 91.97, "bottom" => 178.5, "height" => 11.5 },
        "role" => "body",
        "text" => "正常正文第一行。",
        "style" => { "align" => "center", "font_family" => "FZSSK--GBK1-0", "font_size_pt" => 11.5 }
      },
      {
        "id" => "line-2",
        "bbox" => { "top" => 168.0, "left" => 68.03, "right" => 160.0, "width" => 91.97, "bottom" => 156.5, "height" => 11.5 },
        "role" => "body",
        "text" => "正常正文第二行。",
        "style" => { "align" => "center", "font_family" => "FZSSK--GBK1-0", "font_size_pt" => 11.5 }
      },
      {
        "id" => "line-3",
        "bbox" => { "top" => 146.0, "left" => 68.03, "right" => 429.68, "width" => 361.65, "bottom" => 134.0, "height" => 12.0 },
        "role" => "body",
        "text" => "即使魔兽军团不会死灰复燃，你们也会受到大自然的惩二十尾六",
        "style" => { "align" => "left", "font_family" => "FZSSK--GBK1-0", "font_size_pt" => 12.0 }
      }
    ]
    File.write(page_file, JSON.pretty_generate(payload))

    epub_path = output_dir.join("right-overflow-irregular.epub")
    Ebook::EpubExporter.new(package_dir: output_dir, output_path: epub_path).call

    Zip::File.open(epub_path.to_s) do |zip|
      page_xhtml = zip.read("OEBPS/pages/page-0002.xhtml").force_encoding("UTF-8")

      expect(page_xhtml).to include("即使魔兽军团不会死灰复燃，你们也会受到大自然的惩</p>")
      expect(page_xhtml).not_to include("二十尾六")
      expect(page_xhtml).not_to include("width: 361.65px")
    end
  end

  it "preserves heading serials while stripping trailing body serial pollution" do
    described_class.new(
      pdf_path: files[:pdf].path,
      output_dir: output_dir,
      title: "Worker Export Book",
      source_filename: "worker-export.pdf"
    ).call

    page_file = output_dir.join("pages/page-0002.json")
    payload = JSON.parse(File.read(page_file))
    payload["page_width"] = "428.03"
    payload["page_height"] = "220"
    payload["images"] = []
    payload["directory"] = { "title" => "二 神秘失踪的文物" }
    payload["lines"] = [
      {
        "id" => "line-1",
        "bbox" => { "top" => 200.0, "left" => 83.39, "right" => 251.64, "width" => 168.24, "bottom" => 170.0, "height" => 30.0 },
        "role" => "heading",
        "text" => "二神秘失踪的文物",
        "style" => { "align" => "left", "font_family" => "HYp1gj", "font_size_pt" => 30.0 }
      },
      {
        "id" => "line-2",
        "bbox" => { "top" => 146.0, "left" => 91.56, "right" => 405.68, "width" => 314.13, "bottom" => 134.0, "height" => 12.0 },
        "role" => "body",
        "text" => "讲解员听我这么说，也很惊讶。她走到展柜前，看了二",
        "style" => { "align" => "left", "font_family" => "FZSSK--GBK1-0", "font_size_pt" => 12.0 }
      },
      {
        "id" => "line-3",
        "bbox" => { "top" => 124.0, "left" => 68.03, "right" => 348.66, "width" => 280.63, "bottom" => 112.5, "height" => 11.5 },
        "role" => "body",
        "text" => "看，然后摇了摇头，说：“这个展柜里本来就没有文物。”",
        "style" => { "align" => "center", "font_family" => "FZSSK--GBK1-0", "font_size_pt" => 11.5 }
      }
    ]
    File.write(page_file, JSON.pretty_generate(payload))

    epub_path = output_dir.join("serial-cleanup.epub")
    Ebook::EpubExporter.new(package_dir: output_dir, output_path: epub_path).call

    Zip::File.open(epub_path.to_s) do |zip|
      page_xhtml = zip.read("OEBPS/pages/page-0002.xhtml").force_encoding("UTF-8")

      expect(page_xhtml).to include(">二神秘失踪的文物</h2>")
      expect(page_xhtml).to include(">讲解员听我这么说，也很惊讶。她走到展柜前，看了</p>")
      expect(page_xhtml).not_to include("看了二</p>")
      expect(page_xhtml).to include("font-size: 30.0px")
    end
  end

  it "drops duplicated heading serial pollution when the title itself starts with the same numeral" do
    described_class.new(
      pdf_path: files[:pdf].path,
      output_dir: output_dir,
      title: "Worker Export Book",
      source_filename: "worker-export.pdf"
    ).call

    page_file = output_dir.join("pages/page-0002.json")
    payload = JSON.parse(File.read(page_file))
    payload["page_width"] = "428.03"
    payload["page_height"] = "220"
    payload["images"] = []
    payload["directory"] = { "title" => "十 十二生肖的秘密" }
    payload["lines"] = [
      {
        "id" => "line-1",
        "bbox" => { "top" => 200.0, "left" => 83.39, "right" => 251.64, "width" => 168.24, "bottom" => 170.0, "height" => 30.0 },
        "role" => "heading",
        "text" => "十十二生肖的秘密",
        "style" => { "align" => "left", "font_family" => "HYp1gj", "font_size_pt" => 30.0 }
      }
    ]
    File.write(page_file, JSON.pretty_generate(payload))

    epub_path = output_dir.join("duplicated-heading-serial.epub")
    Ebook::EpubExporter.new(package_dir: output_dir, output_path: epub_path).call

    Zip::File.open(epub_path.to_s) do |zip|
      page_xhtml = zip.read("OEBPS/pages/page-0002.xhtml").force_encoding("UTF-8")

      expect(page_xhtml).to include(">十二生肖的秘密</h2>")
      expect(page_xhtml).not_to include(">十十二生肖的秘密</h2>")
    end
  end

  it "keeps chapter heading text and shifts the hero image when overlap can be resolved" do
    described_class.new(
      pdf_path: files[:pdf].path,
      output_dir: output_dir,
      title: "Worker Export Book",
      source_filename: "worker-export.pdf"
    ).call

    page_file = output_dir.join("pages/page-0002.json")
    payload = JSON.parse(File.read(page_file))
    payload["page_width"] = "428.03"
    payload["page_height"] = "220"
    payload["text"] = ""
    payload["directory"] = { "title" => "十八 “地球勇士”很忙" }
    payload["images"] = [
      {
        "id" => "image-2-1",
        "bbox" => {
          "top" => 200.0,
          "left" => 220.0,
          "right" => 328.42,
          "width" => 108.42,
          "bottom" => 124.63,
          "height" => 75.37
        },
        "role" => "hero_image",
        "type" => "image",
        "image_url" => "/system/ebooks/book_1/page_2/image_1.png",
        "mime_type" => "image/png"
      }
    ]
    payload["lines"] = [
      {
        "id" => "line-1",
        "bbox" => { "top" => 175.0, "left" => 72.05, "right" => 263.86, "width" => 191.81, "bottom" => 145.0, "height" => 30.0 },
        "role" => "heading",
        "text" => "十八“地球勇士”很忙",
        "style" => { "align" => "left", "font_family" => "HYp1gj", "font_size_pt" => 30.0 }
      }
    ]
    File.write(page_file, JSON.pretty_generate(payload))
    source_asset = Dir[output_dir.join("assets/*").to_s].first
    FileUtils.cp(source_asset, output_dir.join("assets/2-image_1#{File.extname(source_asset)}")) if source_asset

    epub_path = output_dir.join("heading-overlap.epub")
    Ebook::EpubExporter.new(package_dir: output_dir, output_path: epub_path).call

    Zip::File.open(epub_path.to_s) do |zip|
      page_xhtml = zip.read("OEBPS/pages/page-0002.xhtml").force_encoding("UTF-8")

      expect(page_xhtml).to include(%(class="page-text-layer page-heading"))
      expect(page_xhtml).to include("地球勇士")
      expect(page_xhtml).to include("left: 287.86px; top: 20.0px; width: 108.42px; height: 75.37px;")
    end
  end

  it "keeps chapter heading text when it only slightly intersects the hero image bbox" do
    described_class.new(
      pdf_path: files[:pdf].path,
      output_dir: output_dir,
      title: "Worker Export Book",
      source_filename: "worker-export.pdf"
    ).call

    page_file = output_dir.join("pages/page-0002.json")
    payload = JSON.parse(File.read(page_file))
    payload["page_width"] = "428.03"
    payload["page_height"] = "220"
    payload["text"] = ""
    payload["directory"] = { "title" => "十八 “地球勇士”很忙" }
    payload["images"] = [
      {
        "id" => "image-2-1",
        "bbox" => {
          "top" => 200.0,
          "left" => 256.27,
          "right" => 364.69,
          "width" => 108.42,
          "bottom" => 124.63,
          "height" => 75.37
        },
        "role" => "hero_image",
        "type" => "image",
        "image_url" => "/system/ebooks/book_1/page_2/image_1.png",
        "mime_type" => "image/png"
      }
    ]
    payload["lines"] = [
      {
        "id" => "line-1",
        "bbox" => { "top" => 175.0, "left" => 72.05, "right" => 263.86, "width" => 191.81, "bottom" => 145.0, "height" => 30.0 },
        "role" => "heading",
        "text" => "十八“地球勇士”很忙",
        "style" => { "align" => "left", "font_family" => "HYp1gj", "font_size_pt" => 30.0 }
      }
    ]
    File.write(page_file, JSON.pretty_generate(payload))
    source_asset = Dir[output_dir.join("assets/*").to_s].first
    FileUtils.cp(source_asset, output_dir.join("assets/2-image_1#{File.extname(source_asset)}")) if source_asset

    epub_path = output_dir.join("heading-light-overlap.epub")
    Ebook::EpubExporter.new(package_dir: output_dir, output_path: epub_path).call

    Zip::File.open(epub_path.to_s) do |zip|
      page_xhtml = zip.read("OEBPS/pages/page-0002.xhtml").force_encoding("UTF-8")

      expect(page_xhtml).to include(%(class="page-text-layer page-heading"))
      expect(page_xhtml).to include("地球勇士")
      expect(page_xhtml).to include("left: 287.86px; top: 20.0px; width: 108.42px; height: 75.37px;")
    end
  end

  it "adds reader-safe side padding and widens page numbers near the page footer" do
    described_class.new(
      pdf_path: files[:pdf].path,
      output_dir: output_dir,
      title: "Worker Export Book",
      source_filename: "worker-export.pdf"
    ).call

    page_file = output_dir.join("pages/page-0002.json")
    payload = JSON.parse(File.read(page_file))
    payload["page_width"] = "428.03"
    payload["page_height"] = "220"
    payload["text"] = ""
    payload["images"] = []
    payload["lines"] = [
      {
        "id" => "line-1",
        "bbox" => { "top" => 80.0, "left" => 68.03, "right" => 350.68, "width" => 282.65, "bottom" => 68.5, "height" => 11.5 },
        "role" => "body",
        "text" => "个发光的徽章是怎么回事？你怎么会突然变得力大无穷？",
        "style" => { "align" => "center", "font_family" => "FZSSK--GBK1-0", "font_size_pt" => 11.5 }
      },
      {
        "id" => "line-2",
        "bbox" => { "top" => 48.0, "left" => 204.1, "right" => 212.6, "width" => 8.5, "bottom" => 37.0, "height" => 11.0 },
        "role" => "body",
        "text" => "1",
        "style" => { "align" => "center", "font_family" => "BankGothicBT-Medium", "font_size_pt" => 11.0 }
      }
    ]
    File.write(page_file, JSON.pretty_generate(payload))

    epub_path = output_dir.join("bottom-safe-area.epub")
    Ebook::EpubExporter.new(package_dir: output_dir, output_path: epub_path).call

    Zip::File.open(epub_path.to_s) do |zip|
      page_xhtml = zip.read("OEBPS/pages/page-0002.xhtml").force_encoding("UTF-8")

      expect(page_xhtml).to include('meta name="viewport" content="width=492.03,height=220.0"')
      expect(page_xhtml).to include('class="page-text-layer page-body page-page-number"')
      expect(page_xhtml).to include('section class="page-canvas" style="width: 492.03px; height: 220.0px; position: relative;')
      expect(page_xhtml).to include('class="page-content-frame" style="padding: 0 32.0px; position: relative;')
      expect(page_xhtml).to match(%r{>1</p>})
      expect(page_xhtml).to match(/page-page-number"\s+style="left: 204\.1px; top: 172\.0px; width: 26\.45px;/)
    end
  end

  it "strips trailing carry-over quote pollution when the next line continues the sentence" do
    described_class.new(
      pdf_path: files[:pdf].path,
      output_dir: output_dir,
      title: "Worker Export Book",
      source_filename: "worker-export.pdf"
    ).call

    page_file = output_dir.join("pages/page-0002.json")
    payload = JSON.parse(File.read(page_file))
    payload["page_width"] = "428.03"
    payload["page_height"] = "220"
    payload["images"] = []
    payload["lines"] = [
      {
        "id" => "line-1",
        "bbox" => { "top" => 168.0, "left" => 91.56, "right" => 405.68, "width" => 314.13, "bottom" => 156.0, "height" => 12.0 },
        "role" => "body",
        "text" => "记者们很快将我围在中间，用相机给我拍照，闪光灯『",
        "style" => { "align" => "left", "font_family" => "FZSSK--GBK1-0", "font_size_pt" => 12.0 }
      },
      {
        "id" => "line-2",
        "bbox" => { "top" => 146.0, "left" => 68.03, "right" => 206.05, "width" => 138.02, "bottom" => 134.5, "height" => 11.5 },
        "role" => "body",
        "text" => "的亮光刺得我睁不开眼睛。",
        "style" => { "align" => "left", "font_family" => "FZSSK--GBK1-0", "font_size_pt" => 11.5 }
      }
    ]
    File.write(page_file, JSON.pretty_generate(payload))

    epub_path = output_dir.join("trailing-quote-cleanup.epub")
    Ebook::EpubExporter.new(package_dir: output_dir, output_path: epub_path).call

    Zip::File.open(epub_path.to_s) do |zip|
      page_xhtml = zip.read("OEBPS/pages/page-0002.xhtml").force_encoding("UTF-8")

      expect(page_xhtml).to include("闪光灯</p>")
      expect(page_xhtml).to include("的亮光刺得我睁不开眼睛。")
      expect(page_xhtml).not_to include("闪光灯『")
    end
  end

  it "removes duplicated carry-over characters after stripping polluted line prefixes" do
    described_class.new(
      pdf_path: files[:pdf].path,
      output_dir: output_dir,
      title: "Worker Export Book",
      source_filename: "worker-export.pdf"
    ).call

    page_file = output_dir.join("pages/page-0002.json")
    payload = JSON.parse(File.read(page_file))
    payload["page_width"] = "428.03"
    payload["page_height"] = "220"
    payload["images"] = []
    payload["lines"] = [
      {
        "id" => "line-1",
        "bbox" => { "top" => 190.0, "left" => 102.9, "right" => 360.0, "width" => 257.1, "bottom" => 178.5, "height" => 11.5 },
        "role" => "body",
        "text" => "我回到家时，浑身都湿透了，累得一根手指头都动不",
        "style" => { "align" => "left", "font_family" => "FZSSK--GBK1-0", "font_size_pt" => 11.5 }
      },
      {
        "id" => "line-2",
        "bbox" => { "top" => 168.0, "left" => 31.03, "right" => 360.0, "width" => 328.97, "bottom" => 156.5, "height" => 11.5 },
        "role" => "body",
        "text" => "IK了了。妈妈坐在客厅的沙发上等我，见我回来了，一把抱",
        "style" => { "align" => "left", "font_family" => "FZSSK--GBK1-0", "font_size_pt" => 11.5 }
      },
      {
        "id" => "line-3",
        "bbox" => { "top" => 146.0, "left" => 31.03, "right" => 326.64, "width" => 295.61, "bottom" => 134.5, "height" => 11.5 },
        "role" => "body",
        "text" => "D住了我——这一整个晚上，她都在为我担惊受怕。",
        "style" => { "align" => "left", "font_family" => "FZSSK--GBK1-0", "font_size_pt" => 11.5 }
      }
    ]
    File.write(page_file, JSON.pretty_generate(payload))

    epub_path = output_dir.join("carry-over-dedupe.epub")
    Ebook::EpubExporter.new(package_dir: output_dir, output_path: epub_path).call

    Zip::File.open(epub_path.to_s) do |zip|
      page_xhtml = zip.read("OEBPS/pages/page-0002.xhtml").force_encoding("UTF-8")

      expect(page_xhtml).to include("了。妈妈坐在客厅的沙发上等我，见我回来了，一把抱")
      expect(page_xhtml).to include("住了我——这一整个晚上，她都在为我担惊受怕。")
      expect(page_xhtml).not_to include("IK了了。")
      expect(page_xhtml).not_to include(">了了。妈妈")
      expect(page_xhtml).not_to include(">D住了我")
    end
  end

  it "keeps full-page rendered image pages at the original viewport width" do
    described_class.new(
      pdf_path: files[:pdf].path,
      output_dir: output_dir,
      title: "Worker Export Book",
      source_filename: "worker-export.pdf"
    ).call

    page_file = output_dir.join("pages/page-0002.json")
    payload = JSON.parse(File.read(page_file))
    payload["page_width"] = "428.03"
    payload["page_height"] = "220"
    payload["text"] = ""
    payload["lines"] = []
    payload["images"] = [
      {
        "id" => "image-2-1",
        "bbox" => {
          "top" => 220.0,
          "left" => 0.0,
          "right" => 428.03,
          "width" => 428.03,
          "bottom" => 0.0,
          "height" => 220.0
        },
        "role" => "hero_image",
        "type" => "image",
        "image_url" => "/system/ebooks/book_1/page_2/image_1.png",
        "mime_type" => "image/png",
        "source_filter" => Ebook::PageImageRenderer::PDFTOCAIRO_FILTER
      }
    ]
    File.write(page_file, JSON.pretty_generate(payload))
    source_asset = Dir[output_dir.join("assets/*").to_s].first
    FileUtils.cp(source_asset, output_dir.join("assets/2-image_1#{File.extname(source_asset)}")) if source_asset

    epub_path = output_dir.join("full-page-image.epub")
    Ebook::EpubExporter.new(package_dir: output_dir, output_path: epub_path).call

    Zip::File.open(epub_path.to_s) do |zip|
      page_xhtml = zip.read("OEBPS/pages/page-0002.xhtml").force_encoding("UTF-8")

      expect(page_xhtml).to include('class="page-full-image"')
      expect(page_xhtml).to include("width=")
      expect(page_xhtml).not_to include("<svg")
      expect(page_xhtml).not_to include('class="page-text-layer')
    end
  end
end
