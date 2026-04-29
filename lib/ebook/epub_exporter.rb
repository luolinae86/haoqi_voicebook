# frozen_string_literal: true

require "cgi"
require "base64"
require "digest"
require "fileutils"
require "json"
require "pathname"
require "tmpdir"
require "zip"
require_relative "pdf_font_extractor"
require_relative "page_image_renderer"

  module Ebook
  class EpubExporter
    DEFAULT_RIGHT_PAGE_PADDING = 64.0
    DEFAULT_READER_SAFE_SIDE_PADDING = 64.0
    PAGE_NUMBER_MIN_WIDTH = 24.0
    PAGE_NUMBER_SIDE_PADDING = 8.0
    HEADING_IMAGE_GAP = 8.0
    TITLE_IMAGE_PADDING = 2.0
    HEADING_IMAGE_OVERLAP_HIDE_RATIO = 0.12
    HEADING_IMAGE_OVERLAP_WIDTH_RATIO = 0.12
    HEADING_IMAGE_OVERLAP_HEIGHT_RATIO = 0.5
    TRAILING_LINE_POLLUTION_CHARS = ["『"].freeze

    def initialize(package_dir:, output_path:, source_pdf_path: nil, font_extractor: nil, page_renderer: nil)
      @package_dir = Pathname.new(package_dir.to_s)
      @output_path = Pathname.new(output_path.to_s)
      @source_pdf_path = source_pdf_path.presence
      @font_extractor = font_extractor
      @page_renderer = page_renderer
    end

    def call
      raise ArgumentError, "导出包目录不存在: #{@package_dir}" unless @package_dir.exist?

      load_package!
      FileUtils.mkdir_p(@output_path.dirname)
      FileUtils.rm_f(@output_path)

      Dir.mktmpdir("ebook-epub") do |tmp_dir|
        root = Pathname.new(tmp_dir)
        build_epub_tree(root)
        pack_epub(root)
      end

      @output_path
    ensure
      close_page_renderer
    end

    private

    def load_package!
      manifest_path = @package_dir.join("manifest.json")
      raise ArgumentError, "manifest.json 不存在: #{manifest_path}" unless manifest_path.exist?

      @manifest = JSON.parse(File.read(manifest_path))
      @book = @manifest.fetch("book")
      @pages = @manifest.fetch("pages").map do |page_entry|
        page_file = @package_dir.join("pages", page_entry.fetch("file"))
        payload = JSON.parse(File.read(page_file))
        payload["directory"] ||= page_entry["directory"]
        payload
      end
      @directories = Array(@manifest["directories"])
      @assets_dir = @package_dir.join("assets")
      @embedded_fonts = resolve_embedded_fonts
      @font_family_lookup = build_font_family_lookup(@embedded_fonts)
    end

    def build_epub_tree(root)
      File.write(root.join("mimetype"), "application/epub+zip")
      FileUtils.mkdir_p(root.join("META-INF"))
      FileUtils.mkdir_p(root.join("OEBPS/pages"))
      FileUtils.mkdir_p(root.join("OEBPS/images"))
      FileUtils.mkdir_p(root.join("OEBPS/fonts"))
      FileUtils.mkdir_p(root.join("OEBPS/styles"))

      File.write(root.join("META-INF/container.xml"), container_xml)
      File.write(root.join("OEBPS/styles/book.css"), stylesheet)

      font_manifest_items = copy_font_files(root)
      page_entries, page_manifest_items, spine_items = write_pages(root)
      manifest_items = [
        { id: "nav", href: "nav.xhtml", media_type: "application/xhtml+xml", properties: "nav" },
        { id: "css", href: "styles/book.css", media_type: "text/css" },
        *font_manifest_items,
        *page_manifest_items
      ]
      File.write(root.join("OEBPS/nav.xhtml"), nav_document(page_entries))
      File.write(root.join("OEBPS/content.opf"), content_opf(manifest_items, spine_items))
    end

    def write_pages(root)
      page_entries = []
      manifest_items = []
      spine_items = []

      @pages.each do |page|
        visible_text_lines = visible_lines(page, dimension(page["page_width"]))
        title_image_assets = render_heading_images(page, visible_text_lines, root, manifest_items)
        href = "pages/page-#{format('%04d', page.fetch('page_number'))}.xhtml"
        image_only = full_page_image_page?(page, visible_text_lines, adjusted_images_for_page(page, visible_text_lines, effective_page_width(page, dimension(page["page_width"]))))
        File.write(root.join("OEBPS", href), page_document(page, root, visible_text_lines:, title_image_assets:))

        item_id = "page-#{page.fetch('page_number')}"
        manifest_items << { id: item_id, href: href, media_type: "application/xhtml+xml" }
        spine_items << item_id
        page_entries << {
          "page_number" => page.fetch("page_number"),
          "href" => href,
          "directory" => page["directory"]
        }

        if image_only
          register_1x_page_image(page, root, manifest_items)
        else
          copy_page_images(page, root, manifest_items)
        end
      end

      [page_entries, manifest_items, spine_items]
    end

    def register_1x_page_image(page, root, manifest_items)
      page_number = page["page_number"]
      filename = "page-#{page_number}.png"
      target = root.join("OEBPS/images", filename)
      return unless target.exist?

      manifest_items << {
        id: "page-image-#{page_number}",
        href: "images/#{filename}",
        media_type: "image/png"
      }
    end

    def copy_page_images(page, root, manifest_items)
      Array(page["images"]).each do |image|
        source = package_asset_for(page["page_number"], image)
        next unless source&.exist?

        target = root.join("OEBPS/images", source.basename.to_s)
        next if target.exist?

        FileUtils.cp(source, target)
        manifest_items << {
          id: "image-#{Digest::SHA256.hexdigest(source.basename.to_s)[0, 12]}",
          href: "images/#{source.basename}",
          media_type: mime_type_for(source.basename.to_s)
        }
      end
    end

    def page_document(page, root, visible_text_lines: nil, title_image_assets: {})
      original_width = dimension(page["page_width"])
      original_height = dimension(page["page_height"])
      visible_text_lines ||= visible_lines(page, original_width)
      width = effective_page_width(page, original_width)
      adjusted_images = adjusted_images_for_page(page, visible_text_lines, width)
      image_only_page = full_page_image_page?(page, visible_text_lines, adjusted_images)

      if image_only_page
        render_result = render_page_image(page["page_number"], dimension(page["page_width"]), dimension(page["page_height"]), root)
        if render_result
          page_width = render_result.fetch(:image_width)
          page_height = render_result.fetch(:image_height)
        else
          page_width = width.round
          page_height = original_height.round
        end
      else
        page_width = width
        page_height = original_height
      end

      body = page_layers(
        page,
        page_width,
        page_height,
        visible_text_lines,
        adjusted_images,
        page_frame_padding(page, width, original_width),
        title_image_assets,
        image_only_page,
        root
      )

      <<~HTML
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="zh-CN">
          <head>
            <title>#{escape_html(page_title(page))}</title>
            <meta name="viewport" content="width=#{page_width},height=#{page_height}"/>
            <style type="text/css">#{critical_page_css(image_only_page)}</style>
            <link rel="stylesheet" type="text/css" href="../styles/book.css"/>
          </head>
          <body class="fixed-layout-page" style="#{body_inline_style(image_only_page)}">
            <section class="page-canvas" style="#{page_canvas_inline_style(page_width, page_height, image_only_page)}">
              #{body}
            </section>
          </body>
        </html>
      HTML
    end

    def render_page_image(page_number, pdf_width, pdf_height, root)
      renderer = page_renderer
      return nil unless renderer&.available?

      cache_key = :"@rendered_page_#{page_number}"
      return instance_variable_get(cache_key) if instance_variable_defined?(cache_key)

      begin
        two_x_renderer = PageImageRenderer.new(
          pdf_path: renderer.instance_variable_get(:@pdf_path),
          scale: 2.0
        )
        rendered = two_x_renderer.render_crop(
          page_number: page_number,
          page_width: pdf_width,
          page_height: pdf_height,
          bbox: { left: 0.0, bottom: 0.0, width: pdf_width, height: pdf_height, top: pdf_height, right: pdf_width }
        )
        instance_variable_set(cache_key, rendered)
        rendered
      rescue PageImageRenderer::RenderUnavailableError
        instance_variable_set(cache_key, nil)
        nil
      end
    end

    def page_layers(page, page_width, page_height, visible_text_lines = nil, images = nil, frame_padding = 0.0, title_image_assets = {}, image_only_page = false, root = nil)
      current_images = Array(images || page["images"])
      if image_only_page && title_image_assets.empty? && Array(visible_text_lines || page["lines"]).empty? && current_images.size == 1
        return <<~HTML
          <div class="page-content-frame" style="#{page_content_frame_inline_style(frame_padding, image_only_page)}">
            #{full_page_image_svg_layer(page["page_number"], current_images.first, page_width, page_height, root)}
          </div>
        HTML
      end

      image_layers = current_images.map do |image|
        image_layer(page["page_number"], image, page_width, page_height)
      end
      title_layers = title_image_assets.values.map { |asset| title_image_layer(asset, page_height) }
      text_layers = Array(visible_text_lines || visible_lines(page, page_width))
                    .reject { |line| line["role"] == "heading" && title_image_assets.key?(line["id"]) }
                    .map { |line| line_layer(line, page_height, page_width) }

      if text_layers.empty? && page["text"].present?
        text_layers = page["text"].to_s.lines.each_with_index.map do |line, index|
          fallback_text_layer(line, index)
        end
      end

      <<~HTML
        <div class="page-content-frame" style="#{page_content_frame_inline_style(frame_padding, image_only_page)}">
          #{(image_layers + title_layers + text_layers).join("\n")}
        </div>
      HTML
    end

    def image_layer(page_number, image, page_width, page_height)
      asset = package_asset_for(page_number, image)
      return "" unless asset&.exist?

      bbox = image.fetch("bbox")
      left = dimension(bbox["left"])
      top = page_height - dimension(bbox["top"])
      width = display_width_for_image(image, bbox, page_width)
      height = display_height_for_image(image, bbox, page_height)

      <<~HTML.strip
        <img class="page-image-layer" src="../images/#{escape_html(asset.basename.to_s)}" alt="page #{page_number} image"
             style="left: #{css_px(left)}; top: #{css_px(top)}; width: #{css_px(width)}; height: #{css_px(height)}; position: absolute; display: block; margin: 0; padding: 0; border: 0; max-width: none; max-height: none;"/>
      HTML
    end

    def full_page_image_svg_layer(page_number, image, page_width, page_height, root = nil)
      # Write the 2× rendered PNG directly — no SVG.
      # viewport = image pixel dimensions, so no layout shift.
      rendered = root ? render_page_image(page_number, dimension(page_width), dimension(page_height), root) : nil

      if rendered && root
        filename = "page-#{page_number}.png"
        target = root.join("OEBPS/images", filename)
        File.binwrite(target, rendered[:bytes])
        href = "../images/#{escape_html(filename)}"
        img_w = rendered[:image_width]
        img_h = rendered[:image_height]
      else
        href = "../images/#{escape_html(package_asset_for(page_number, image)&.basename.to_s)}"
        img_w = dimension(page_width)
        img_h = dimension(page_height)
      end

      <<~HTML.strip
        <img class="page-full-image" src="#{href}" alt="page #{page_number}"
             width="#{img_w}" height="#{img_h}"
             style="display: block; margin: 0; padding: 0; border: 0; max-width: none; max-height: none;"/>
      HTML
    end

    def title_image_layer(asset, page_height)
      bbox = asset.fetch(:bbox)
      left = dimension(bbox[:left])
      top = page_height - dimension(bbox[:top])

      <<~HTML.strip
        <img class="page-title-image" src="../images/#{escape_html(asset.fetch(:filename))}" alt="#{escape_html(asset.fetch(:alt).to_s)}"
             style="left: #{css_px(left)}; top: #{css_px(top)}; width: #{css_px(bbox[:width])}; height: #{css_px(bbox[:height])}; position: absolute; display: block; margin: 0; padding: 0; border: 0; max-width: none; max-height: none;"/>
      HTML
    end

    def critical_page_css(image_only_page)
      overflow = image_only_page ? "hidden" : "visible"

      [
        "html,body{margin:0;padding:0;background:#ffffff;width:100%;height:100%;overflow:#{overflow};}",
        "body.fixed-layout-page{width:100%;height:100%;overflow:#{overflow};}",
        ".page-canvas{position:relative;margin:0 auto;background:#ffffff;overflow:#{overflow};}",
        ".page-content-frame{position:relative;box-sizing:border-box;width:100%;height:100%;overflow:#{overflow};}",
        ".page-image-layer,.page-title-image{position:absolute;display:block;margin:0;padding:0;border:0;max-width:none;max-height:none;}",
        ".page-full-image{display:block;margin:0;padding:0;border:0;max-width:none;max-height:none;}"
      ].join
    end

    def body_inline_style(image_only_page)
      overflow = image_only_page ? "hidden" : "visible"
      "margin: 0; padding: 0; background: #ffffff; width: 100%; height: 100%; overflow: #{overflow};"
    end

    def page_canvas_inline_style(page_width, page_height, image_only_page)
      overflow = image_only_page ? "hidden" : "visible"
      "width: #{css_px(page_width)}; height: #{css_px(page_height)}; position: relative; overflow: #{overflow}; margin: 0 auto; background: #ffffff;"
    end

    def page_content_frame_inline_style(frame_padding, image_only_page)
      overflow = image_only_page ? "hidden" : "visible"
      "padding: 0 #{css_px(frame_padding)}; position: relative; box-sizing: border-box; width: 100%; height: 100%; overflow: #{overflow};"
    end

    def line_layer(line, page_height, page_width)
      bbox = line.fetch("bbox")
      style = (line["style"] || {}).with_indifferent_access
      page_number = page_number_line?(line, page_height)
      left = dimension(bbox["left"])
      top = page_height - dimension(bbox["top"])
      embedded_family = embedded_font_family(style)
      width = display_width_for_line(
        line: line,
        bbox: bbox,
        page_width: page_width,
        left: left,
        font_size: style[:font_size_pt].to_f,
        role: line["role"],
        embedded_font_family: embedded_family,
        page_height: page_height
      )
      height = [dimension(bbox["height"]), style[:font_size_pt].to_f].max
      align = style[:align].presence || "left"
      font_weight = style[:font_weight].presence || "normal"
      font_style = style[:font_style].presence || "normal"
      font_size = resolved_font_size(
        text: line["text"].to_s,
        width: width,
        original_font_size: style[:font_size_pt].to_f,
        role: line["role"],
        embedded_font_family: embedded_family
      )
      tag = line["role"] == "heading" ? "h2" : "p"
      font_stack = font_stack_for(style, embedded_family)
      classes = ["page-text-layer", line["role"] == "heading" ? "page-heading" : "page-body"]
      classes << "page-page-number" if page_number

      inline_styles = [
        "left: #{css_px(left)}",
        "top: #{css_px(top)}",
        "width: #{css_px(width)}",
        "min-height: #{css_px(height)}",
        "text-align: #{align}",
        "font-size: #{css_px(font_size)}",
        "font-weight: #{font_weight}",
        "font-style: #{font_style}"
      ]
      inline_styles << "font-family: #{font_stack}" if font_stack.present?

      <<~HTML.strip
        <#{tag} class="#{classes.join(' ')}"
             style="#{inline_styles.join('; ')};">#{escape_html(line["text"].to_s)}</#{tag}>
      HTML
    end

    def visible_lines(page, page_width)
      lines = Array(page["lines"])
      return [] if lines.empty?

      strip_side_noise = side_noise_page?(lines, page_width)
      title_fragments = title_fragment_candidates(page)
      serial_profile = chapter_serial_profile(page)
      anchor_profile = build_anchor_profile(page, page_width, strip_side_noise, title_fragments)
      repaired_lines = []

      lines.each_with_index do |line, index|
        next if line_hidden_by_image?(line, page["images"])
        next if heading_overlaps_image?(line, page["images"], page_width)

        next_line = next_visible_text_line(lines, index)
        sanitized_text = sanitize_line_text(
          line,
          page_width,
          strip_side_noise,
          title_fragments,
          serial_profile,
          next_line,
          repaired_lines.last
        )
        next if sanitized_text.blank?

        sanitized_line = line.deep_dup
        sanitized_line["text"] = sanitized_text
        if right_overflow_line?(line, page_width)
          trim_overflow_text!(sanitized_line, page_width, anchor_profile)
        end
        if polluted_line?(line, page_width)
          repair_polluted_line!(sanitized_line, repaired_lines.last, anchor_profile)
        elsif side_noise_shifted_line?(line, lines, index, page_width)
          repair_polluted_line!(sanitized_line, repaired_lines.last, anchor_profile)
        elsif right_overflow_line?(line, page_width)
          repair_right_title_polluted_line!(sanitized_line, page_width, anchor_profile)
        end

        repaired_lines << sanitized_line
      end

      repaired_lines
    end

    def line_hidden_by_image?(line, images)
      Array(images).any? do |image|
        overlap_ratio(line["bbox"], image["bbox"]) >= 0.75
      end
    end

    def heading_overlaps_image?(line, images, page_width)
      return false unless line["role"] == "heading"

      bbox = line["bbox"] || {}
      line_width = [dimension(bbox["width"]), 1.0].max
      line_height = [dimension(bbox["height"]), 1.0].max

      Array(images).any? do |image|
        overlap = overlap_dimensions(bbox, image["bbox"])
        next false unless overlap
        next false if heading_image_shift(line, image["bbox"], page_width).positive?

        area_ratio = (overlap[:width] * overlap[:height]) / (line_width * line_height)
        width_ratio = overlap[:width] / line_width
        height_ratio = overlap[:height] / line_height

        area_ratio >= HEADING_IMAGE_OVERLAP_HIDE_RATIO &&
          width_ratio >= HEADING_IMAGE_OVERLAP_WIDTH_RATIO &&
          height_ratio >= HEADING_IMAGE_OVERLAP_HEIGHT_RATIO
      end
    end

    def sanitize_line_text(line, page_width, strip_side_noise, title_fragments, serial_profile, next_line, previous_line)
      text = line["text"].to_s
      return if text.blank?
      return if standalone_side_noise?(line, page_width)

      text = sanitize_heading_text(text, line["role"], serial_profile)

      if trailing_line_polluted?(text, next_line)
        text = strip_trailing_line_pollution(text)
      end
      if polluted_line?(line, page_width)
        text = text.sub(/\A[A-Za-z]{1,3}(?=[\p{Han}“”"'‘’《〈（【])/u, "")
        text = strip_duplicated_carry_over(text, previous_line&.dig("text").to_s)
      end
      if right_title_polluted?(line, page_width, title_fragments)
        text = strip_title_fragment_suffix(text, title_fragments)
      end
      if trailing_serial_polluted?(line, text, serial_profile, next_line)
        text = strip_trailing_serial(text, serial_profile)
      end

      text.presence
    end

    def sanitize_heading_text(text, role, serial_profile)
      return text unless role == "heading"

      serial = serial_profile[:serial].to_s
      remainder = serial_profile[:remainder].to_s
      return text if serial.blank? || remainder.blank?
      return text unless remainder.start_with?(serial)
      return remainder if text == "#{serial}#{remainder}"

      text
    end

    def strip_duplicated_carry_over(text, previous_text)
      return text if text.blank? || previous_text.blank?
      return text if previous_text.match?(/[。！？!?…]([”’」』】])?\z/u)

      text.sub(/\A([\p{Han}])\1(?=[，。！？；：])/u, '\1')
    end

    def trailing_line_polluted?(text, next_line)
      return false if text.blank? || next_line.blank?
      return false unless TRAILING_LINE_POLLUTION_CHARS.any? { |char| text.end_with?(char) }

      next_text = next_line["text"].to_s
      next_text.match?(/\A[\p{Han}A-Za-z0-9“”"'‘’《〈（【]/u)
    end

    def strip_trailing_line_pollution(text)
      text.sub(/[#{Regexp.escape(TRAILING_LINE_POLLUTION_CHARS.join)}]+\z/u, "")
    end

    def side_noise_page?(lines, page_width)
      lines.count { |line| standalone_side_noise?(line, page_width) } >= 4
    end

    def standalone_side_noise?(line, page_width)
      bbox = line["bbox"] || {}
      style = line["style"] || {}
      text = line["text"].to_s.strip

      return false if text.empty?
      return false unless left_margin?(bbox, page_width)
      return true if text.match?(/\A[A-Za-z]{1,3}[.…·•]{1,6}\z/) && dimension(bbox["width"]) <= 120

      return false unless style["font_size_pt"].to_f.positive? && style["font_size_pt"].to_f <= 9.5
      return false unless dimension(bbox["width"]) <= 14

      text.match?(/\A[A-Za-z]{1,3}\z/)
    end

    def polluted_line?(line, page_width)
      bbox = line["bbox"] || {}
      text = line["text"].to_s

      left_margin?(bbox, page_width) && text.match?(/\A[A-Za-z]{1,3}(?=[\p{Han}“”"'‘’《〈（【])/u)
    end

    def side_noise_shifted_line?(line, lines, index, page_width)
      return false unless line["role"] == "body"
      return false if polluted_line?(line, page_width)
      return false if standalone_side_noise?(line, page_width)

      bbox = line["bbox"] || {}
      text = line["text"].to_s.strip
      return false unless left_margin?(bbox, page_width)
      return false unless text.match?(/\A[\p{Han}“”"'‘’《〈（【]/u)
      return false unless text.length >= 8 || dimension(bbox["width"]) >= [page_width * 0.28, 120.0].max

      nearby_side_noise_line?(lines, index, page_width, bbox)
    end

    def nearby_side_noise_line?(lines, index, page_width, bbox)
      (-3..3).any? do |offset|
        next false if offset.zero?

        candidate = lines[index + offset]
        next false unless candidate && standalone_side_noise?(candidate, page_width)

        candidate_bbox = candidate["bbox"] || {}
        (dimension(candidate_bbox["top"]) - dimension(bbox["top"])).abs <= 24.0
      end
    end

    def build_anchor_profile(page, page_width, strip_side_noise, title_fragments)
      anchor_stats = Hash.new { |hash, key| hash[key] = { count: 0, aligns: Hash.new(0), advances: [] } }

      Array(page["lines"]).each_with_index do |line, index|
        next if line_hidden_by_image?(line, page["images"])
        next if standalone_side_noise?(line, page_width)
        next if polluted_line?(line, page_width)
        next if side_noise_shifted_line?(line, Array(page["lines"]), index, page_width)
        next if right_title_polluted?(line, page_width, title_fragments)
        next unless line["role"] == "body"

        bbox = line["bbox"] || {}
        left = dimension(bbox["left"])
        next unless left > [page_width * 0.12, 40.0].max

        stats = anchor_stats[left]
        stats[:count] += 1
        stats[:aligns][normalized_align(line)] += 1

        visual_length = visual_length(line["text"])
        if visual_length.positive? && dimension(bbox["width"]).positive?
          stats[:advances] << (dimension(bbox["width"]) / visual_length)
        end
      end

      ordered = anchor_stats.sort_by { |left, stats| [-stats[:count], left] }
      base_left = ordered.first&.first
      max_indent_delta = maximum_indent_delta(anchor_stats, base_left)
      indent_left = ordered
                      .map(&:first)
                      .select do |left|
                        base_left.present? &&
                          left > (base_left + 4.0) &&
                          left <= (base_left + max_indent_delta)
                      end
                      .min

      {
        anchors: anchor_stats,
        base_left: base_left,
        indent_left: indent_left,
        average_advance: average_advance(anchor_stats)
      }
    end

    def maximum_indent_delta(anchor_stats, base_left)
      return 36.0 if base_left.blank?

      average = average_advance(anchor_stats)
      [[average * 3.2, 20.0].max, 36.0].min.round(2)
    end

    def repair_polluted_line!(line, previous_line, anchor_profile)
      bbox = line["bbox"] || {}
      right = dimension(bbox["right"])
      return if right <= 0

      left = repaired_left_for_line(line, previous_line, anchor_profile)
      return unless left.present? && right > left

      bbox["left"] = left
      bbox["width"] = dimension(right - left)
      line["bbox"] = bbox

      style = (line["style"] || {}).deep_dup
      style["align"] = repaired_align_for_line(line, left, bbox["width"], anchor_profile)
      line["style"] = style
    end

    def repair_right_title_polluted_line!(line, page_width, anchor_profile)
      bbox = line["bbox"] || {}
      left = dimension(bbox["left"])
      return if left <= 0

      width = estimated_line_width(line["text"], anchor_profile, left, page_width)
      bbox["width"] = width
      bbox["right"] = dimension(left + width)
      line["bbox"] = bbox

      style = (line["style"] || {}).deep_dup
      style["align"] = repaired_align_for_line(line, left, width, anchor_profile)
      line["style"] = style
    end

    def trim_overflow_text!(line, page_width, anchor_profile)
      bbox = line["bbox"] || {}
      left = dimension(bbox["left"])
      return if left <= 0

      text = line["text"].to_s
      max_width = [dimension(page_width) - left, 1.0].max
      tolerance = [average_advance_for_left(anchor_profile, left) * 0.45, 4.0].max

      while text.present? && raw_estimated_line_width(text, anchor_profile, left) > (max_width + tolerance)
        text = text[0...-1]
      end

      line["text"] = text
    end

    def repaired_left_for_line(line, previous_line, anchor_profile)
      base_left = anchor_profile[:base_left]
      indent_left = anchor_profile[:indent_left]
      return base_left unless indent_left.present?

      paragraph_start?(line["text"].to_s, previous_line&.dig("text").to_s) ? indent_left : base_left
    end

    def repaired_align_for_line(line, left, width, anchor_profile)
      stats = anchor_profile[:anchors][left]
      dominant_align = stats[:aligns].max_by { |_align, count| count }&.first || "left"
      return "left" if short_line?(line["text"], width, anchor_profile[:average_advance])

      dominant_align
    end

    def estimated_line_width(text, anchor_profile, left, page_width)
      expected = raw_estimated_line_width(text, anchor_profile, left)
      max_width = [dimension(page_width) - left, 1.0].max
      [[expected.round(2), max_width].min, 1.0].max.round(2)
    end

    def raw_estimated_line_width(text, anchor_profile, left)
      (visual_length(text) * average_advance_for_left(anchor_profile, left)).round(2)
    end

    def paragraph_start?(text, previous_text)
      return false if text.blank?
      return true if previous_text.blank?
      return false if continuation_start?(text)

      previous_text.match?(/[。！？!?…]([”’」』】])?\z/u)
    end

    def continuation_start?(text)
      prefixes = %w[
        的 了 地 得 着 而 而且 并 并且 并非 并不 并未 并将 把 被 给 从 向 往 于 与 及 和 或
        再 又 也 还 都 就 才 便 仍 却 但 会 能 可 要 来 去 让 因此 所以 然后 于是 那么 这么 这样
      ]
      prefixes.any? { |prefix| text.start_with?(prefix) }
    end

    def short_line?(text, width, average_advance)
      return true if width.to_f <= 0

      expected_width = visual_length(text) * average_advance
      expected_width < (dimension(width) * 0.78)
    end

    def average_advance(anchor_stats)
      advances = anchor_stats.values.flat_map { |stats| stats[:advances] }
      return 10.0 if advances.empty?

      (advances.sum / advances.size).round(2)
    end

    def average_advance_for_left(anchor_profile, left)
      stats = anchor_profile[:anchors][left]
      advances = stats ? stats[:advances] : []
      return anchor_profile[:average_advance] if advances.blank?

      (advances.sum / advances.size).round(2)
    end

    def visual_length(text)
      text.to_s.each_char.sum do |char|
        if char.match?(/[A-Za-z0-9]/)
          0.62
        elsif char.match?(/\s/)
          0.3
        else
          1.0
        end
      end
    end

    def normalized_align(line)
      align = line.dig("style", "align").to_s
      %w[left center right justify].include?(align) ? align : "left"
    end

    def next_visible_text_line(lines, index)
      lines[(index + 1)..].to_a.find do |candidate|
        candidate["role"] == "body" && candidate["text"].to_s.present?
      end
    end

    def chapter_serial_profile(page)
      title = page.dig("directory", "title").to_s.strip
      serial = title[/\A([一二三四五六七八九十百千万零〇两\d]+)/u, 1].to_s
      remainder = title.sub(/\A#{Regexp.escape(serial)}\s*/u, "")
      {
        serial: serial,
        remainder: remainder
      }
    end

    def trailing_serial_polluted?(line, text, serial_profile, next_line)
      return false unless line["role"] == "body"

      serial = serial_profile[:serial].to_s
      return false if serial.blank? || text.blank?
      return false unless text.end_with?(serial)

      next_text = next_line&.dig("text").to_s
      return false if next_text.blank?
      return false unless next_text.match?(/\A[\p{Han}“”"'‘’《〈（【]/u)

      previous_char = text[0...-serial.length].to_s[-1]
      previous_char&.match?(/[\p{Han}”’」』】!?。，“”、；：]/u)
    end

    def strip_trailing_serial(text, serial_profile)
      serial = serial_profile[:serial].to_s
      return text if serial.blank?

      text.sub(/#{Regexp.escape(serial)}\z/u, "")
    end

    def resolved_font_size(text:, width:, original_font_size:, role:, embedded_font_family:)
      [original_font_size.to_f, 1.0].max
    end

    def effective_page_width(page, original_width)
      (original_width + page_right_padding(page)).round(2)
    end

    def display_width_for_line(line:, bbox:, page_width:, left:, font_size:, role:, embedded_font_family:, page_height:)
      base_width = dimension(bbox["width"])
      if page_number_line?(line, page_height)
        base_width = [base_width, page_number_display_width(line["text"], font_size)].max
      end
      max_width = [dimension(page_width) - left, 1.0].max
      [[base_width.round(2), max_width].min, 1.0].max.round(2)
    end

    def page_right_padding(page)
      return 0.0 if Array(page["images"]).any? { |image| full_page_rendered_image?(image, image["bbox"] || {}) }

      DEFAULT_READER_SAFE_SIDE_PADDING
    end

    def page_frame_padding(page, viewport_width, original_width)
      return 0.0 if Array(page["images"]).any? { |image| full_page_rendered_image?(image, image["bbox"] || {}) }

      [(dimension(viewport_width) - dimension(original_width)) / 2.0, 0.0].max.round(2)
    end

    def bottom_clearance_for_line(line, original_height)
      bbox = line["bbox"] || {}
      explicit_bottom = dimension(bbox["bottom"])
      return explicit_bottom if explicit_bottom.positive? || bbox.key?("bottom")

      top = original_height - dimension(bbox["top"])
      height = [dimension(bbox["height"]), line.dig("style", "font_size_pt").to_f].max
      [original_height - (top + height), 0.0].max.round(2)
    end

    def page_number_line?(line, page_height)
      return false unless line["role"] == "body"

      text = line["text"].to_s.strip
      return false unless text.match?(/\A\d+\z/)

      bbox = line["bbox"] || {}
      dimension(bbox["width"]) <= 50.0 && bottom_clearance_for_line(line, page_height) <= 72.0
    end

    def page_number_display_width(text, font_size)
      digits = [text.to_s.strip.length, 1].max
      glyph_width = [font_size.to_f * 0.95, 8.0].max
      [(digits * glyph_width) + (PAGE_NUMBER_SIDE_PADDING * 2), PAGE_NUMBER_MIN_WIDTH].max.round(2)
    end

    def adjusted_images_for_page(page, visible_text_lines, original_width)
      images = Array(page["images"]).map(&:deep_dup)
      headings = Array(visible_text_lines).select { |line| line["role"] == "heading" }
      return images if images.empty? || headings.empty?

      images.each do |image|
        bbox = image["bbox"] || {}
        headings.each do |line|
          shift = heading_image_shift(line, bbox, original_width)
          next unless shift.positive?

          bbox["left"] = dimension(bbox["left"]) + shift
          bbox["right"] = dimension(bbox["right"]) + shift
          image["bbox"] = bbox
          break
        end
      end

      images
    end

    def heading_image_shift(line, image_bbox, page_width)
      line_bbox = line["bbox"] || {}
      return 0.0 unless vertically_conflicts?(line_bbox, image_bbox)

      line_right = dimension(line_bbox["right"])
      image_left = dimension(image_bbox["left"])
      image_right = dimension(image_bbox["right"])
      return 0.0 unless image_left >= dimension(line_bbox["left"])

      gap = image_left - line_right
      needed_shift = heading_image_gap(line) - gap
      return 0.0 unless needed_shift.positive?

      available_shift = dimension(page_width) - image_right
      return 0.0 if available_shift < needed_shift

      needed_shift.round(2)
    end

    def heading_image_gap(line)
      [HEADING_IMAGE_GAP, line.dig("style", "font_size_pt").to_f * 0.8].max.round(2)
    end

    def vertically_conflicts?(line_bbox, image_bbox)
      line_top = dimension(line_bbox["top"])
      line_bottom = dimension(line_bbox["bottom"])
      image_top = dimension(image_bbox["top"])
      image_bottom = dimension(image_bbox["bottom"])

      [line_top, image_top].min > [line_bottom, image_bottom].max
    end

    def fitted_font_size(text, width, original_font_size, role)
      base_size = [original_font_size.to_f, 1.0].max
      return base_size if text.blank? || width.to_f <= 0

      fit_ratio = role == "heading" ? 0.95 : 0.99
      fitted = (dimension(width) / [visual_length(text), 1.0].max) * fit_ratio
      [base_size, fitted.round(2)].min.clamp(1.0, base_size)
    end

    def right_title_polluted?(line, page_width, title_fragments)
      return false unless line["role"] == "body"
      return false if title_fragments.empty?

      bbox = line["bbox"] || {}
      right = dimension(bbox["right"])
      return false unless right > (dimension(page_width) + 0.5)

      title_fragment_suffix(line["text"].to_s, title_fragments).present?
    end

    def right_overflow_line?(line, page_width)
      return false unless line["role"] == "body"

      bbox = line["bbox"] || {}
      dimension(bbox["right"]) > (dimension(page_width) + 0.5)
    end

    def strip_title_fragment_suffix(text, title_fragments)
      suffix = title_fragment_suffix(text, title_fragments)
      return text unless suffix.present?

      stripped = text.sub(/#{Regexp.escape(suffix)}\z/u, "")
      stripped.present? ? stripped : text
    end

    def title_fragment_suffix(text, title_fragments)
      title_fragments.find { |fragment| text.end_with?(fragment) }
    end

    def title_fragment_candidates(page)
      raw_titles = []
      raw_titles << page.dig("directory", "title").to_s
      raw_titles.concat(Array(page["lines"]).select { |line| line["role"] == "heading" }.map { |line| line["text"].to_s })

      raw_titles.flat_map do |raw_title|
        title_variants(raw_title).flat_map do |variant|
          normalized = normalize_title_fragment_source(variant)
          next [] if normalized.length < 3

          max_length = [normalized.length, 6].min
          fragments = (3..max_length).map { |length| normalized[0, length] }
          fragments.concat(scrambled_title_fragment_candidates(normalized))
          fragments
        end
      end.compact.uniq.sort_by { |fragment| -fragment.length }
    end

    def title_variants(raw_title)
      trimmed = raw_title.to_s.strip
      return [] if trimmed.empty?

      without_serial = trimmed.sub(/\A[一二三四五六七八九十百千万零〇两\d]+\s*/u, "")
      [trimmed, without_serial].uniq
    end

    def normalize_title_fragment_source(title)
      title.to_s.gsub(/[^\p{Han}A-Za-z0-9]/u, "")
    end

    def scrambled_title_fragment_candidates(normalized_title)
      match = normalized_title.match(/\A([一二三四五六七八九十百千万零〇两\d]{2,})([\p{Han}A-Za-z0-9]{1,})\z/u)
      return [] unless match

      serial = match[1]
      core = match[2]
      return [] if core.blank?

      candidates = []
      candidates << "#{serial[0...-1]}#{core[0, 1]}#{serial[-1]}"
      candidates << "#{serial[0...-1]}#{core[0, 2]}#{serial[-1]}" if core.length >= 2
      candidates.compact.select { |fragment| fragment.length >= 3 }
    end

    def left_margin?(bbox, page_width)
      dimension(bbox["left"]) <= [page_width * 0.12, 40.0].max
    end

    def overlap_ratio(line_bbox, image_bbox)
      overlap = overlap_dimensions(line_bbox, image_bbox)
      return 0.0 unless overlap
      return 0.0 if line_bbox.blank?

      line_area = dimension(line_bbox["width"]) * dimension(line_bbox["height"])
      return 0.0 if line_area <= 0

      (overlap[:width] * overlap[:height]) / line_area
    end

    def overlap_dimensions(line_bbox, image_bbox)
      return if line_bbox.blank? || image_bbox.blank?

      left = [dimension(line_bbox["left"]), dimension(image_bbox["left"])].max
      right = [dimension(line_bbox["right"]), dimension(image_bbox["right"])].min
      bottom = [dimension(line_bbox["bottom"]), dimension(image_bbox["bottom"])].max
      top = [dimension(line_bbox["top"]), dimension(image_bbox["top"])].min
      return unless right > left && top > bottom

      {
        width: right - left,
        height: top - bottom
      }
    end

    def fallback_text_layer(line, index)
      <<~HTML.strip
        <p class="page-text-fallback" style="top: #{css_px(20 + (index * 24))};">#{escape_html(clean_role_marker(line))}</p>
      HTML
    end

    def nav_document(page_entries)
      toc_items = @directories.map do |directory|
        entry = page_entries.find { |page| page.dig("directory", "start_page_number") == directory["start_page_number"] }
        next unless entry

        <<~HTML.strip
          <li><a href="#{escape_html(entry["href"])}">#{escape_html(directory["title"])}</a></li>
        HTML
      end.compact.join("\n")

      page_list_items = page_entries.map do |entry|
        <<~HTML.strip
          <li><a href="#{escape_html(entry["href"])}">第 #{entry["page_number"]} 页</a></li>
        HTML
      end.join("\n")

      <<~HTML
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="zh-CN">
          <head>
            <title>目录</title>
            <link rel="stylesheet" type="text/css" href="styles/book.css"/>
          </head>
          <body>
            <nav epub:type="toc" id="toc">
              <h1>目录</h1>
              <ol>
                #{toc_items}
              </ol>
            </nav>
            <nav epub:type="page-list" id="page-list">
              <h2>页码</h2>
              <ol>
                #{page_list_items}
              </ol>
            </nav>
          </body>
        </html>
      HTML
    end

    def content_opf(manifest_items, spine_items)
      manifest_xml = manifest_items.map do |item|
        properties = item[:properties] ? %( properties="#{item[:properties]}") : ""
        %(    <item id="#{item[:id]}" href="#{item[:href]}" media-type="#{item[:media_type]}"#{properties}/>)
      end.join("\n")
      spine_xml = spine_items.map { |id| %(    <itemref idref="#{id}"/>) }.join("\n")
      spread_mode = full_page_image_book? ? "none" : "auto"

      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:identifier id="bookid">urn:uuid:#{Digest::SHA256.hexdigest(@book["title"].to_s)[0, 12]}</dc:identifier>
            <dc:title>#{escape_html(@book["title"].to_s)}</dc:title>
            <dc:language>zh-CN</dc:language>
            <dc:creator>#{escape_html(@book["author"].to_s.presence || "未知作者")}</dc:creator>
            <meta property="dcterms:modified">#{Time.current.utc.strftime("%Y-%m-%dT%H:%M:%SZ")}</meta>
            <meta property="rendition:layout">pre-paginated</meta>
            <meta property="rendition:orientation">auto</meta>
            <meta property="rendition:spread">#{spread_mode}</meta>
          </metadata>
          <manifest>
        #{manifest_xml}
          </manifest>
          <spine page-progression-direction="ltr">
        #{spine_xml}
          </spine>
        </package>
      XML
    end

    def container_xml
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles>
            <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
      XML
    end

    def stylesheet
      <<~CSS
        #{font_face_rules}

        html, body {
          margin: 0;
          padding: 0;
          background: #ffffff;
        }

        body.fixed-layout-page {
          width: 100%;
          height: 100%;
          overflow: visible;
        }

        .page-canvas {
          position: relative;
          overflow: visible;
          margin: 0 auto;
          background: #ffffff;
        }

        .page-content-frame {
          position: relative;
          box-sizing: border-box;
          width: 100%;
          height: 100%;
        }

        .page-image-layer {
          position: absolute;
          display: block;
        }

        .page-title-image {
          position: absolute;
          display: block;
          z-index: 3;
        }

        .page-full-image {
          display: block;
        }

        .page-text-layer {
          position: absolute;
          display: block;
          margin: 0;
          padding: 0;
          line-height: 1;
          color: #000000;
          white-space: nowrap;
          word-break: keep-all;
          overflow-wrap: normal;
          overflow: visible;
          writing-mode: horizontal-tb;
          text-rendering: geometricPrecision;
          font-synthesis: none;
        }

        .page-heading {
          letter-spacing: -0.04em;
        }

        .page-body {
          letter-spacing: 0;
        }

        .page-page-number {
          z-index: 2;
        }

        .page-text-fallback {
          position: absolute;
          left: 24px;
          right: 24px;
          margin: 0;
          line-height: 1.4;
        }
      CSS
    end

    def pack_epub(root)
      Zip::OutputStream.open(@output_path.to_s) do |zip|
        zip.put_next_entry("mimetype", nil, nil, Zip::Entry::STORED)
        zip.write("application/epub+zip")
      end

      Zip::File.open(@output_path.to_s, create: true) do |zip|
        Dir[root.join("**/*")].sort.each do |file|
          next if File.directory?(file)
          next if File.basename(file) == "mimetype"

          entry_name = Pathname.new(file).relative_path_from(root).to_s
          zip.add(entry_name, file)
        end
      end
    end

    def package_asset_for(page_number, image)
      image_url = image["image_url"] || image[:image_url]
      return if image_url.blank?

      @assets_dir.join("#{page_number}-#{File.basename(image_url)}")
    end

    def page_title(page)
      page.dig("directory", "title").presence || "第 #{page["page_number"]} 页"
    end

    def render_heading_images(page, visible_text_lines, root, manifest_items)
      renderer = page_renderer
      return {} unless renderer&.available?

      Array(visible_text_lines).select { |line| line["role"] == "heading" }.each_with_index.each_with_object({}) do |(line, index), assets|
        bbox = expanded_title_bbox(line["bbox"], page["page_width"], page["page_height"])
        rendered = renderer.render_crop(
          page_number: page.fetch("page_number"),
          page_width: dimension(page["page_width"]),
          page_height: dimension(page["page_height"]),
          bbox: bbox
        )
        filename = "title-#{page.fetch('page_number')}-#{index + 1}.#{rendered[:extension]}"
        target = root.join("OEBPS/images", filename)
        File.binwrite(target, rendered[:bytes])
        manifest_items << {
          id: "title-image-#{page.fetch('page_number')}-#{index + 1}",
          href: "images/#{filename}",
          media_type: rendered[:mime_type]
        }
        assets[line["id"]] = {
          filename: filename,
          alt: line["text"].to_s,
          bbox: bbox
        }
      rescue PageImageRenderer::RenderUnavailableError
        next
      end
    end

    def expanded_title_bbox(bbox, page_width, page_height)
      left = [dimension(bbox["left"]) - TITLE_IMAGE_PADDING, 0.0].max
      bottom = [dimension(bbox["bottom"]) - TITLE_IMAGE_PADDING, 0.0].max
      right = [dimension(bbox["right"]) + TITLE_IMAGE_PADDING, dimension(page_width)].min
      top = [dimension(bbox["top"]) + TITLE_IMAGE_PADDING, dimension(page_height)].min

      {
        left: left.round(2),
        bottom: bottom.round(2),
        width: (right - left).round(2),
        height: (top - bottom).round(2),
        right: right.round(2),
        top: top.round(2)
      }
    end

    def display_width_for_image(image, bbox, page_width)
      return dimension(page_width) if full_page_rendered_image?(image, bbox)

      dimension(bbox["width"])
    end

    def display_height_for_image(image, bbox, page_height)
      return dimension(page_height) if full_page_rendered_image?(image, bbox)

      dimension(bbox["height"])
    end

    def full_page_rendered_image?(image, bbox)
      PageImageRenderer::RENDER_FILTERS.include?(image["source_filter"].to_s) &&
        dimension(bbox["left"]).zero? &&
        dimension(bbox["bottom"]).zero? &&
        dimension(bbox["width"]).positive? &&
        dimension(bbox["height"]).positive?
    end

    def full_page_image_page?(page, visible_text_lines = nil, images = nil)
      Array(visible_text_lines || page["lines"]).empty? &&
        page["text"].to_s.blank? &&
        Array(images || page["images"]).any? { |image| full_page_rendered_image?(image, image["bbox"] || {}) }
    end

    def full_page_image_book?
      Array(@pages).present? && Array(@pages).all? do |page|
        full_page_image_page?(page)
      end
    end

    def dimension(value)
      value.to_f.round(2)
    end

    def css_px(value)
      "#{dimension(value)}px"
    end

    def mime_type_for(filename)
      case File.extname(filename).downcase
      when ".png" then "image/png"
      when ".jpg", ".jpeg" then "image/jpeg"
      when ".jpx" then "image/jpx"
      when ".ttf" then "font/ttf"
      when ".otf" then "font/otf"
      when ".woff" then "font/woff"
      when ".woff2" then "font/woff2"
      else "application/octet-stream"
      end
    end

    def resolve_embedded_fonts
      extractor = @font_extractor || build_font_extractor
      return [] unless extractor

      Array(
        extractor.call(
          used_font_names: used_font_names,
          used_font_families: used_font_families
        )
      ).map(&:with_indifferent_access)
    end

    def build_font_extractor
      pdf_path = @source_pdf_path.presence || @book["source_pdf_path"].presence
      return unless pdf_path.present?

      path = Pathname.new(pdf_path.to_s)
      return unless path.exist?

      PdfFontExtractor.new(pdf_path: path)
    end

    def page_renderer
      @page_renderer ||= build_page_renderer
    end

    def build_page_renderer
      return @page_renderer if defined?(@page_renderer) && @page_renderer
      return unless @source_pdf_path.present?

      path = Pathname.new(@source_pdf_path.to_s)
      return unless path.exist?

      PageImageRenderer.new(pdf_path: path)
    rescue StandardError
      nil
    end

    def close_page_renderer
      @page_renderer&.close if defined?(@page_renderer) && @page_renderer.respond_to?(:close)
    end

    def used_font_names
      @pages.flat_map do |page|
        Array(page["lines"]).map { |line| line.dig("style", "font_name") }
      end.compact_blank.uniq
    end

    def used_font_families
      @pages.flat_map do |page|
        Array(page["lines"]).map { |line| line.dig("style", "font_family") }
      end.compact_blank.uniq
    end

    def build_font_family_lookup(fonts)
      fonts.each_with_object({}) do |font, lookup|
        aliases = Array(font[:aliases]).presence || [font[:source_name], font[:normalized_name]]
        aliases.compact_blank.each do |alias_name|
          lookup[alias_name] = font[:css_family]
          lookup[normalize_font_name(alias_name)] = font[:css_family]
        end
      end
    end

    def copy_font_files(root)
      @embedded_fonts.map do |font|
        target = root.join("OEBPS/fonts", font[:filename].to_s)
        File.binwrite(target, font[:data].to_s)
        {
          id: "font-#{Digest::SHA256.hexdigest(font[:filename].to_s)[0, 12]}",
          href: "fonts/#{font[:filename]}",
          media_type: font[:media_type]
        }
      end
    end

    def font_face_rules
      @embedded_fonts.map do |font|
        <<~CSS
          @font-face {
            font-family: '#{escape_html(font[:css_family].to_s)}';
            src: url('../fonts/#{escape_html(font[:filename].to_s)}') format('#{escape_html(font[:format].to_s)}');
            font-weight: normal;
            font-style: normal;
          }
        CSS
      end.join("\n")
    end

    def font_stack_for(style, embedded_family = embedded_font_family(style))
      fallback_family = style[:font_family].presence
      raw_font_name = style[:font_name].presence

      families = [embedded_family, fallback_family, raw_font_name, "sans-serif"].compact_blank.uniq
      return if families.empty?

      families.map do |family|
        family == "sans-serif" ? family : "'#{escape_html(family)}'"
      end.join(", ")
    end

    def embedded_font_family(style)
      [style[:font_name], style[:font_family]].compact_blank.each do |name|
        embedded = @font_family_lookup[name] || @font_family_lookup[normalize_font_name(name)]
        return embedded if embedded.present?
      end

      nil
    end

    def normalize_font_name(font_name)
      normalized = font_name.to_s.sub(/\A[A-Z0-9]{6}\+/, "")
      normalized = normalized.split(",").first.to_s
      normalized.strip
    end

    def clean_role_marker(line)
      line.to_s.gsub(/\[(TITLE|BODY)\]\s*/, "").strip
    end

    def escape_html(value)
      CGI.escapeHTML(value.to_s)
    end
  end
end
