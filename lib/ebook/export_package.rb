# frozen_string_literal: true

require "fileutils"
require "json"
require "pathname"
require_relative "epub_exporter"

module Ebook
  class ExportPackage
    def initialize(book:, output_dir:)
      @book = book
      @output_dir = Pathname.new(output_dir.to_s)
    end

    def call
      FileUtils.rm_rf(@output_dir)
      pages_dir = @output_dir.join("pages")
      assets_dir = @output_dir.join("assets")
      FileUtils.mkdir_p(pages_dir)
      FileUtils.mkdir_p(assets_dir)

      manifest = {
        book: {
          id: @book.id,
          title: @book.name,
          author: @book.author,
          page_count: @book.page_count,
          imported_at: @book.imported_at,
          source_pdf_filename: @book.source_pdf_filename,
          source_pdf_path: @book.source_pdf_path,
          ebook_checksum: @book.ebook_checksum
        },
        directories: [],
        pages: []
      }

      directories = []
      @book.ebook_pages.ordered.find_each do |page|
        content = sanitized_content_for_export(
          normalized_content(page),
          page_number: page.page_number,
          page_width: page.page_width,
          page_height: page.page_height
        )
        page_payload = {
          page_number: page.page_number,
          page_width: page.page_width,
          page_height: page.page_height,
          word_count: page.word_count,
          image_count: page.image_count,
          text: content[:text].presence || page.plain_text,
          lines: content[:lines] || [],
          images: content[:images] || [],
          directory: content[:directory]
        }

        page_file = pages_dir.join(format("page-%04d.json", page.page_number))
        File.write(page_file, JSON.pretty_generate(page_payload))
        manifest[:pages] << {
          page_number: page.page_number,
          file: page_file.basename.to_s,
          word_count: page.word_count,
          image_count: page.image_count,
          directory: content[:directory]
        }
        directories << content[:directory].merge(end_page_number: page.page_number) if content[:directory].present?

        copy_images(content[:images], assets_dir, page.page_number)
      end

      manifest[:directories] = collapse_directories(directories)
      File.write(@output_dir.join("manifest.json"), JSON.pretty_generate(manifest))
      @output_dir
    end

    private

    def copy_images(images, assets_dir, page_number)
      Array(images).each do |image|
        image_block = image.respond_to?(:with_indifferent_access) ? image.with_indifferent_access : image
        next if image_block[:image_url].blank?

        # OSS URL — skip local copy, EPUB will reference OSS directly
        next if image_block[:image_url].to_s.start_with?("https://")

        source = Rails.public_path.join(image_block[:image_url].delete_prefix("/"))
        next unless File.exist?(source)

        target = assets_dir.join("#{page_number}-#{File.basename(source)}")
        FileUtils.cp(source, target)
      end
    end

    def normalized_content(page)
      content = page.rich_content
      return content.with_indifferent_access if content.is_a?(Hash)

      image_blocks = Array(content).select { |block| block["type"] == "image" || block[:type] == "image" }
      text_value = Array(content).select { |block| block["type"] == "text" || block[:type] == "text" }
                                 .map { |block| block["text"] || block[:text] }
                                 .join("\n")

      {
        text: text_value.presence || page.plain_text,
        lines: [],
        images: image_blocks,
        directory: nil
      }.with_indifferent_access
    end

    def sanitized_content_for_export(content, page_number:, page_width:, page_height:)
      raw_page = {
        "page_number" => page_number,
        "page_width" => page_width,
        "page_height" => page_height,
        "text" => content[:text].to_s,
        "lines" => deep_stringify(content[:lines] || []),
        "images" => deep_stringify(content[:images] || []),
        "directory" => deep_stringify(content[:directory])
      }
      lines = page_sanitizer.send(:visible_lines, raw_page, page_width.to_f)
      lines.each do |line|
        next unless line["marker"].present?

        line["text_with_role"] = "#{line['marker']} #{line['text']}\n"
      end

      export_text = if lines.any?
                      lines.map { |line| line["text_with_role"] }.join
                    else
                      content[:text]
                    end

      content.merge(text: export_text, lines: lines)
    end

    def page_sanitizer
      @page_sanitizer ||= Ebook::EpubExporter.new(
        package_dir: @output_dir,
        output_path: @output_dir.join(".export-sanitizer.epub")
      )
    end

    def deep_stringify(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, item), result|
          result[key.to_s] = deep_stringify(item)
        end
      when Array
        value.map { |item| deep_stringify(item) }
      else
        value
      end
    end

    def collapse_directories(directories)
      directories.each_with_object([]) do |directory, collapsed|
        if collapsed.last &&
           collapsed.last[:title] == directory[:title] &&
           collapsed.last[:source] == directory[:source]
          collapsed.last[:end_page_number] = directory[:end_page_number]
        else
          collapsed << directory.deep_symbolize_keys
        end
      end
    end
  end
end
