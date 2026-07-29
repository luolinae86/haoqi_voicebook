# frozen_string_literal: true

require "digest"
require "fileutils"
require "pathname"
require "pdf-reader"
require_relative "page_image_renderer"
require_relative "toc_mapper"

module Ebook
  # 将 PDF 电子书导入为可按页读取的结构化文本和主图
  class PdfImporter
    LINE_TOLERANCE = 2.0

    def initialize(book:, pdf_path:, source_filename: nil,
                   source_pdf_oss_key: nil,
                   public_root: Rails.public_path,
                   storage_root: Rails.public_path.join("system/ebooks"),
                   page_renderer: nil,
                   force_image_pages: false,
                   image_exporter_oss_service: nil,
                   image_exporter_oss_prefix: nil)
      @book = book
      @pdf_path = Pathname.new(pdf_path.to_s)
      @source_filename = source_filename.presence || @pdf_path.basename.to_s
      @source_pdf_oss_key = source_pdf_oss_key.presence
      @public_root = Pathname.new(public_root.to_s)
      @storage_root = Pathname.new(storage_root.to_s).join("book_#{book.id || 'new'}")
      @page_renderer = page_renderer
      @force_image_pages = force_image_pages == true
      @image_exporter_oss_service = image_exporter_oss_service
      @image_exporter_oss_prefix = image_exporter_oss_prefix
    end

    def call
      raise ArgumentError, "PDF 文件不存在: #{@pdf_path}" unless @pdf_path.exist?

      @book.update!(import_status: :processing, import_error_message: nil)
      reader = PDF::Reader.new(@pdf_path.to_s)
      renderer = @page_renderer || PageImageRenderer.new(pdf_path: @pdf_path)
      force_image_pages = page_image_mode?(reader)
      toc_mapping = TocMapper.new(reader: reader).call
      total_word_count = 0
      checksum = Digest::SHA256.file(@pdf_path).hexdigest
      current_directory = nil

      Book.transaction do
        @book.ebook_pages.delete_all
        FileUtils.rm_rf(@storage_root)

        # 安全地收集所有可访问的页面
        accessible_pages = []
        reader.pages.each do |page|
          begin
            page_num = page.number
            accessible_pages << page
          rescue StandardError => e
            Rails.logger.warn("[PdfImporter] Cannot access page: #{e.message}")
            next
          end
        end

        accessible_pages.each do |page|
          begin
            # Always walk the page for text to resolve directory headings
            receiver = PdfPageReceiver.new
            page.walk(receiver)
            text_content = build_text_content(page, receiver.runs)

            if force_image_pages
              import_as_image_page(page, renderer, toc_mapping[:page_map], text_content, current_directory)
              # Update current_directory from this page's text for subsequent pages
              resolved = resolve_directory(
                page_number: page.number,
                text_content: text_content,
                directory_map: toc_mapping[:page_map],
                current_directory: current_directory
              )
              current_directory = resolved if resolved
            else
              receiver = PdfPageReceiver.new
              page.walk(receiver)
              content, current_directory, page_geometry = build_content(
                page,
                receiver,
                directory_map: toc_mapping[:page_map],
                current_directory: current_directory,
                renderer: renderer,
                force_image_pages: false
              )
              plain_text = sanitize_text(content[:text])
              word_count = count_words(plain_text)

              @book.ebook_pages.create!(
                page_number: page.number,
                page_width: page_geometry[:width],
                page_height: page_geometry[:height],
                plain_text: plain_text,
                rich_content: sanitize_content(content),
                word_count: word_count,
                block_count: content[:lines].size + content[:images].size,
                image_count: content[:images].size
              )

              total_word_count += word_count
            end
          rescue PDF::Reader::MalformedPDFError, PDF::Reader::Error => e
            # 跳过有问题的页面，继续处理其他页面
            Rails.logger.warn("[PdfImporter] Skipping page #{page.number rescue '?'}: #{e.message}")
            next
          rescue StandardError => e
            # 捕获其他可能的错误
            Rails.logger.warn("[PdfImporter] Skipping page #{page.number rescue '?'}: #{e.class}: #{e.message}")
            next
          end
        end

        @book.update!(
          content_type: :ebook,
          word_count: total_word_count,
          page_count: accessible_pages.size,
          source_pdf_filename: @source_filename,
          source_pdf_path: @source_pdf_oss_key.presence || @pdf_path.to_s,
          ebook_checksum: checksum,
          imported_at: Time.current,
          import_status: :ready,
          import_error_message: nil
        )
      end

      @book
    rescue StandardError => e
      @book.update!(import_status: :failed, import_error_message: sanitize_text(e.message)) if @book.persisted?
      raise
    ensure
      renderer&.close if defined?(renderer) && renderer.respond_to?(:close)
    end

    private

    # 导入单页为图片（PDF 强制图片模式）
    def import_as_image_page(page, renderer, directory_map = {}, text_content = {}, current_directory = nil)
      return unless renderer

      full_page = forced_page_image_candidate(page, renderer, enabled: true)
      return unless full_page

      exporter = ImageExporter.new(
        objects: page.objects,
        public_root: @public_root,
        storage_root: @storage_root,
        oss_service: @image_exporter_oss_service,
        oss_prefix: @image_exporter_oss_prefix
      )

      image_info = begin
        exporter.export_rendered(
          rendered: renderer.render_crop(
            page_number: page.number,
            page_width: page.width,
            page_height: page.height,
            bbox: full_page[:render_box],
            right_bleed: 0.0
          ),
          page_number: page.number,
          image_number: 1
        )
      rescue StandardError => e
        Rails.logger.warn("[PdfImporter] Failed to render page #{page.number}: #{e.message}")
        nil
      end

      return unless image_info

      mapped_directory = resolve_directory(
        page_number: page.number,
        text_content: text_content,
        directory_map: directory_map,
        current_directory: current_directory
      )
      rich_content = {
        text: "",
        lines: [],
        images: [{
          id: "image-#{page.number}-1",
          type: "image",
          role: "hero_image",
          mime_type: image_info[:mime_type],
          image_url: image_info[:image_url],
          bbox: {
            left: 0.0,
            bottom: 0.0,
            right: page.width.to_f,
            top: page.height.to_f,
            width: page.width.to_f,
            height: page.height.to_f
          }
        }],
        directory: mapped_directory&.deep_dup
      }

      @book.ebook_pages.create!(
        page_number: page.number,
        page_width: page.width.to_f,
        page_height: page.height.to_f,
        image_url: image_info[:image_url],
        rich_content: rich_content,
        word_count: 0,
        block_count: 1,
        image_count: 1
      )
    end

    def build_content(page, receiver, directory_map:, current_directory:, renderer:, force_image_pages: false)
      text_content = build_text_content(page, receiver.runs)
      resolved_directory = resolve_directory(
        page_number: page.number,
        text_content: text_content,
        directory_map: directory_map,
        current_directory: current_directory
      )
      page_render_image = forced_page_image_candidate(page, renderer, enabled: force_image_pages) ||
                          image_only_page_candidate(page, text_content[:lines], renderer) ||
                          text_over_image_page_candidate(page, receiver.image_runs, text_content[:lines])
      export_text_content = page_render_image ? { text: "", lines: [] } : text_content
      images = build_image_blocks(
        page,
        page_render_image ? [page_render_image] : receiver.image_runs,
        renderer: renderer,
        text_lines: text_content[:lines],
        selected_images: page_render_image ? [page_render_image] : nil
      )
      page_geometry = export_page_geometry(page, page_render_image)

      [{
        text: export_text_content[:text],
        lines: export_text_content[:lines],
        images: images,
        directory: resolved_directory
      }, resolved_directory, page_geometry]
    end

    def build_text_content(page, runs)
      return { text: "", lines: [] } if runs.empty?

      lines = group_runs_into_lines(runs).map { |line_runs| build_line(line_runs) }
      body_font_size = median(lines.map { |line| line[:font_size] })

      normalized_lines = lines.each_with_index.map do |line, index|
        role = line_role(line, body_font_size, page.width)
        next if role == "sidebar"

        marker = role_marker(role)
        text_with_role = "#{marker} #{line[:text]}\n"

        {
          id: "line-#{page.number}-#{index + 1}",
          role: role,
          text: line[:text],
          marker: marker,
          text_with_role: text_with_role,
          bbox: build_bbox(
            line[:left],
            line[:bottom],
            line[:right] - line[:left],
            line[:top] - line[:bottom]
          ),
          style: {
            font_size_pt: line[:font_size].round(2),
            align: paragraph_alignment(line, page.width),
            font_label: line[:font_label],
            font_name: line[:font_name],
            font_family: line[:font_family],
            font_weight: line[:font_weight],
            font_style: line[:font_style]
          }
        }
      end.compact

      {
        text: normalized_lines.map { |line| line[:text_with_role] }.join,
        lines: normalized_lines
      }
    end

    def build_image_blocks(page, image_runs, renderer:, text_lines:, selected_images: nil)
      exporter = ImageExporter.new(
        objects: page.objects,
        public_root: @public_root,
        storage_root: @storage_root,
        oss_service: @image_exporter_oss_service,
        oss_prefix: @image_exporter_oss_prefix
      )

      images_to_export = selected_images || select_primary_images(page, image_runs, text_lines: text_lines)

      images_to_export.each_with_index.filter_map do |image, index|
        visible_box = image.fetch(:visible_box)
        render_box = image[:render_box] || visible_box
        export_box = image[:export_box] || visible_box

        begin
          exported = if render_image_crop?(image, renderer)
                       exporter.export_rendered(
                         rendered: renderer.render_crop(
                           page_number: page.number,
                           page_width: page.width,
                           page_height: page.height,
                           bbox: render_box,
                           right_bleed: render_right_bleed_for_image(page, image)
                         ),
                         page_number: page.number,
                         image_number: index + 1
                       )
                     else
                       exporter.export(xobject: image[:xobject], page_number: page.number, image_number: index + 1)
                     end
        rescue ImageExporter::UnsupportedImageError => e
          Rails.logger.warn("Skip unsupported image on page #{page.number}: #{e.message}")
          next
        rescue PageImageRenderer::RenderUnavailableError => e
          Rails.logger.warn("Skip page render on page #{page.number}: #{e.message}")
          next
        end

        {
          id: "image-#{page.number}-#{index + 1}",
          type: "image",
          role: "hero_image",
          image_url: exported[:image_url],
          mime_type: exported[:mime_type],
          image_width: exported[:image_width],
          image_height: exported[:image_height],
          source_filter: exported[:filter],
          bbox: build_bbox(export_box[:left], export_box[:bottom], export_box[:width], export_box[:height])
        }
      end
    end

    def group_runs_into_lines(runs)
      runs.sort.each_with_object([]) do |run, lines|
        if lines.last && (lines.last.first.y - run.y).abs <= [run.font_size * 0.35, LINE_TOLERANCE].max
          lines.last << run
        else
          lines << [run]
        end
      end
    end

    def build_line(line_runs)
      sorted_runs = line_runs.sort_by(&:x)
      left = sorted_runs.map(&:x).min.to_f
      right = sorted_runs.map(&:endx).max.to_f
      bottom = sorted_runs.map(&:y).min.to_f
      font_size = sorted_runs.map(&:font_size).max.to_f
      text = sorted_runs.map(&:text).join
      dominant_run = dominant_font_run(sorted_runs)

      {
        text: text.strip,
        left: left,
        right: right,
        bottom: bottom,
        top: bottom + font_size,
        font_size: font_size,
        font_label: dominant_run&.font_label,
        font_name: dominant_run&.font_name,
        font_family: dominant_run&.font_family,
        font_weight: dominant_run&.font_weight || "normal",
        font_style: dominant_run&.font_style || "normal"
      }
    end

    def dominant_font_run(sorted_runs)
      sorted_runs.max_by do |run|
        [
          run.text.to_s.gsub(/\s+/, "").length,
          run.width.to_f,
          run.font_size.to_f
        ]
      end
    end

    def line_role(line, body_font_size, page_width)
      return "sidebar" if line[:left] >= page_width * 0.82 && line[:right] >= page_width * 0.9
      return "heading" if line[:font_size] >= body_font_size + 4
      return "heading" if centered_line?(line, page_width) && line[:font_size] >= body_font_size + 2 && line[:text].length <= 20

      "body"
    end

    def role_marker(role)
      role == "heading" ? "[TITLE]" : "[BODY]"
    end

    def paragraph_alignment(line, page_width)
      centered_line?(line, page_width) ? "center" : "left"
    end

    def centered_line?(line, page_width)
      left_margin = line[:left]
      right_margin = page_width - line[:right]
      (left_margin - right_margin).abs <= 20
    end

    def select_primary_images(page, image_runs, text_lines:)
      return [] if image_runs.blank?

      visible_images = image_runs.filter_map do |image|
        visible_box = visible_image_box(image, page.width, page.height)
        next unless visible_box

        image.merge(
          visible_box: visible_box,
          image_mask: image[:xobject].hash[:ImageMask] == true,
          source_filter: Array(image[:xobject].hash[:Filter]).first.to_s
        )
      end
      return [] if visible_images.empty?

      composite_candidate = composite_page_candidate(visible_images, page.width, page.height)
      return [composite_candidate] if composite_candidate

      heading_line = text_lines.find { |line| line[:role] == "heading" }
      candidates = visible_images.reject do |image|
        reject_image_candidate?(
          image,
          page_width: page.width,
          page_height: page.height,
          heading_line: heading_line,
          text_lines: text_lines
        )
      end
      return [] if candidates.empty?

      preferred_candidates = preferred_top_candidates(candidates, page_height: page.height, heading_line: heading_line)
      [preferred_candidates.max_by { |image| image_priority(image, page.width, page.height, heading_line: heading_line) }]
    end

    def reject_image_candidate?(image, page_width:, page_height:, heading_line:, text_lines:)
      top_logo = top_logo_candidate?(image, page_height, heading_line)

      return true if side_image?(image, page_width, page_height) && !top_logo
      return true if small_mask_artifact?(image, page_width, page_height) && !top_logo
      return true if text_overlay_artifact?(image, text_lines) && !top_logo

      false
    end

    def preferred_top_candidates(candidates, page_height:, heading_line:)
      top_candidates = candidates.select { |image| top_logo_candidate?(image, page_height, heading_line) }
      top_candidates.presence || candidates
    end

    def image_priority(image, page_width, page_height, heading_line:)
      box = image[:visible_box]

      [
        top_logo_candidate?(image, page_height, heading_line) ? 1 : 0,
        image[:image_mask] ? 0 : 1,
        edge_distance_score(box, page_width),
        image_top(image),
        visible_area(image)
      ]
    end

    def side_image?(image, page_width, page_height)
      box = image[:visible_box]
      edge_aligned = box[:left] <= page_width * 0.06 || (page_width - (box[:left] + box[:width])) <= page_width * 0.06
      edge_aligned &&
        box[:width] <= page_width * 0.2 &&
        box[:height] >= page_height * 0.18
    end

    def top_logo_candidate?(image, page_height, heading_line)
      box = image[:visible_box]
      near_top = image_top(image) >= page_height * 0.78
      return false unless near_top

      compact_shape = box[:height] <= page_height * 0.18
      near_heading = heading_line.present? && heading_adjacent?(box, heading_line[:bbox])
      compact_shape || near_heading
    end

    def heading_adjacent?(image_box, heading_bbox)
      image_right = image_box[:left] + image_box[:width]
      image_top = image_box[:bottom] + image_box[:height]
      vertical_gap = [(heading_bbox[:bottom].to_f - image_box[:bottom]).abs, (image_top - heading_bbox[:top].to_f).abs].min
      horizontal_gap = if image_right < heading_bbox[:left].to_f
                         heading_bbox[:left].to_f - image_right
                       elsif heading_bbox[:right].to_f < image_box[:left]
                         image_box[:left] - heading_bbox[:right].to_f
                       else
                         0
                       end

      vertical_gap <= 90 && horizontal_gap <= 140
    end

    def small_mask_artifact?(image, page_width, page_height)
      return false unless image[:image_mask]
      return false if large_mask_candidate?(image, page_width, page_height)

      box = image[:visible_box]
      box[:width] <= page_width * 0.28 && box[:height] <= page_height * 0.18
    end

    def large_mask_candidate?(image, page_width, page_height)
      box = image[:visible_box]
      box[:width] >= page_width * 0.42 || box[:height] >= page_height * 0.28 || visible_area(image) >= (page_width * page_height * 0.12)
    end

    def text_overlay_artifact?(image, text_lines)
      return false unless image[:image_mask]

      overlaps = Array(text_lines).count do |line|
        bbox = line[:bbox]
        next false unless bbox

        overlapping_boxes?(image[:visible_box], bbox)
      end
      overlaps >= 2
    end

    def overlapping_boxes?(box_a, box_b)
      box_a[:left] < box_b[:right].to_f &&
        (box_a[:left] + box_a[:width]) > box_b[:left].to_f &&
        box_a[:bottom] < box_b[:top].to_f &&
        (box_a[:bottom] + box_a[:height]) > box_b[:bottom].to_f
    end

    def edge_distance_score(box, page_width)
      distance = [
        box[:left],
        page_width - (box[:left] + box[:width])
      ].min
      -distance
    end

    def composite_page_candidate(images, page_width, page_height)
      base_raster = images.select { |image| !image[:image_mask] && near_full_page?(image[:visible_box], page_width, page_height) }
                          .min_by { |image| image[:visible_box][:left].abs }
      return unless base_raster

      mask = images.find { |image| image[:image_mask] && large_mask_candidate?(image, page_width, page_height) }
      return unless mask

      base_raster.merge(
        visible_box: { left: 0.0, bottom: 0.0, width: page_width, height: page_height },
        force_render: true,
        composite_mask: true
      )
    end

    def near_full_page?(box, page_width, page_height)
      box[:width] >= page_width * 0.95 && box[:height] >= page_height * 0.95
    end

    def image_top(image)
      image[:visible_box][:bottom] + image[:visible_box][:height]
    end

    def image_area(image)
      image[:visible_box][:width] * image[:visible_box][:height]
    end

    def visible_area(image)
      image_area(image)
    end

    def visible_image_box(image, page_width, page_height)
      left = [[image[:left].to_f, 0].max, page_width].min
      bottom = [[image[:bottom].to_f, 0].max, page_height].min
      right = [[image[:left].to_f + image[:width].to_f, 0].max, page_width].min
      top = [[image[:bottom].to_f + image[:height].to_f, 0].max, page_height].min
      width = right - left
      height = top - bottom
      return if width <= 1 || height <= 1

      { left: left, bottom: bottom, width: width, height: height }
    end

    def resolve_directory(page_number:, text_content:, directory_map:, current_directory:)
      mapped_directory = directory_map[page_number]
      return mapped_directory.deep_dup if mapped_directory.present?

      heading = text_content[:lines].find { |line| line[:role] == "heading" }
      if heading.present?
        return {
          title: heading[:text],
          toc_page_number: nil,
          start_page_number: page_number,
          level: 1,
          source: "heading"
        }
      end

      current_directory&.deep_dup
    end

    def renderer_available?(renderer)
      renderer.present? && renderer.respond_to?(:available?) && renderer.available?
    end

    def render_image_crop?(image, renderer)
      renderer_available?(renderer) && (image[:image_mask] || image[:force_render])
    end

    def render_right_bleed_for_image(page, image)
      return 0.0 if image[:disable_right_bleed]
      return 0.0 unless near_full_page?(image[:visible_box], page.width, page.height)

      Ebook::PageImageRenderer::DEFAULT_RIGHT_BLEED
    end

    def image_only_page_candidate(page, text_lines, renderer)
      return if text_lines.present?
      return unless renderer_available?(renderer)

      full_page_candidate_for(page)
    end

    def forced_page_image_candidate(page, renderer, enabled:)
      return unless enabled
      return unless renderer_available?(renderer)

      full_page_candidate_for(page)
    end

    def text_over_image_page_candidate(page, image_runs, text_lines)
      return if text_lines.size < 6

      visible_images = image_runs.filter_map do |image|
        visible_box = visible_image_box(image, page.width, page.height)
        next unless visible_box

        image.merge(
          visible_box: visible_box,
          image_mask: image[:xobject].hash[:ImageMask] == true
        )
      end

      full_page_raster = visible_images.find do |image|
        !image[:image_mask] && near_full_page?(image[:visible_box], page.width, page.height)
      end
      return unless full_page_raster

      overlapping_lines = text_lines.count do |line|
        bbox = line[:bbox]
        bbox && overlapping_boxes?(full_page_raster[:visible_box], bbox)
      end
      return unless overlapping_lines >= [text_lines.size * 0.75, 6].max

      full_page_raster.merge(
        visible_box: { left: 0.0, bottom: 0.0, width: page.width, height: page.height },
        force_render: true,
        overlay_page: true
      )
    end

    def build_bbox(left, bottom, width, height)
      {
        left: left.round(2),
        bottom: bottom.round(2),
        width: width.round(2),
        height: height.round(2),
        right: (left + width).round(2),
        top: (bottom + height).round(2)
      }
    end

    def sanitize_text(text)
      return text if text.blank?

      text.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
    end

    def sanitize_content(content)
      return content unless content.is_a?(Hash)

      content.transform_values do |v|
        case v
        when String
          sanitize_text(v)
        when Hash
          sanitize_content(v)
        when Array
          v.map { |item| item.is_a?(Hash) ? sanitize_content(item) : item }
        else
          v
        end
      end
    end

    def median(values)
      sorted = values.compact.sort
      return 12 if sorted.empty?

      sorted[sorted.length / 2]
    end

    def export_page_geometry(page, page_render_image)
      export_box = page_render_image && (page_render_image[:export_box] || page_render_image[:visible_box])
      return { width: export_box[:width].round(2), height: export_box[:height].round(2) } if export_box

      { width: page.width, height: page.height }
    end

    def full_page_candidate_for(page)
      render_box = visible_page_box(page)

      {
        visible_box: { left: 0.0, bottom: 0.0, width: render_box[:width], height: render_box[:height] },
        render_box: render_box,
        export_box: { left: 0.0, bottom: 0.0, width: render_box[:width], height: render_box[:height] },
        force_render: true,
        image_mask: false,
        image_only_page: true,
        disable_right_bleed: true
      }
    end

    def visible_page_box(page)
      page_attributes = page.respond_to?(:attributes) ? page.attributes : {}
      raw_box = %i[CropBox TrimBox ArtBox].filter_map { |key| normalized_page_box(page_attributes[key]) }.first
      return raw_box if raw_box

      { left: 0.0, bottom: 0.0, width: page.width.to_f, height: page.height.to_f }
    end

    def normalized_page_box(raw_box)
      values = Array(raw_box).map(&:to_f)
      return if values.length != 4

      left, bottom, right, top = values
      width = right - left
      height = top - bottom
      return if width <= 1 || height <= 1

      { left: left, bottom: bottom, width: width, height: height }
    end

    def page_image_mode?(reader)
      @force_image_pages || image_only_pdf?(reader)
    end

    def image_only_pdf?(reader)
      reader.pages.none? { |page| native_page_text?(page) }
    end

    def native_page_text?(page)
      page.text.to_s.gsub(/\s+/, "").present?
    end

    def count_words(text)
      text.to_s.gsub(/\[(TITLE|BODY)\]\s*/, "").gsub(/\s+/, "").length
    end
  end
end
