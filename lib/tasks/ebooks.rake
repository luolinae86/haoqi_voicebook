# frozen_string_literal: true

namespace :ebooks do
  desc "导入 PDF 并将结构化结果导出到下载目录"
  task :import, %i[pdf_path title output_dir epub_output] => :environment do |_task, args|
    pdf_path = args[:pdf_path].presence || ENV["PDF_PATH"]
    raise ArgumentError, "请提供 PDF_PATH 或 pdf_path 参数" if pdf_path.blank?

    title = args[:title].presence || ENV["TITLE"].presence || File.basename(pdf_path, ".pdf")
    output_dir = args[:output_dir].presence || ENV["OUTPUT_DIR"].presence ||
      File.expand_path("~/Downloads/#{title}")
    epub_output = args[:epub_output].presence || ENV["EPUB_OUTPUT"].presence
    export_epub = ENV["SKIP_EPUB"] != "1"

    book = Book.find_or_initialize_by(title: title)
    book.assign_attributes(status: :published, content_type: :ebook)
    book.save! if book.new_record?

    Ebook::LocalExportWorker.new(
      book: book,
      pdf_path: pdf_path,
      title: title,
      output_dir: output_dir,
      source_filename: File.basename(pdf_path),
      export_epub: export_epub,
      epub_output: epub_output
    ).call
  end

  desc "根据现有导出包（manifest/pages/assets）重新生成 EPUB"
  task :build_epub, %i[package_dir epub_output source_pdf_path] => :environment do |_task, args|
    package_dir = args[:package_dir].presence || ENV["PACKAGE_DIR"]
    raise ArgumentError, "请提供 PACKAGE_DIR 或 package_dir 参数" if package_dir.blank?

    package_dir = Pathname.new(package_dir.to_s)
    manifest = JSON.parse(File.read(package_dir.join("manifest.json")))
    title = manifest.dig("book", "title")
    epub_output = args[:epub_output].presence || ENV["EPUB_OUTPUT"].presence || package_dir.join("#{title}.epub")
    source_pdf_path = args[:source_pdf_path].presence || ENV["SOURCE_PDF_PATH"].presence || manifest.dig("book", "source_pdf_path")

    path = Ebook::EpubExporter.new(
      package_dir: package_dir,
      output_path: epub_output,
      source_pdf_path: source_pdf_path
    ).call
    puts "EPUB 文件: #{path}"
  end
end
