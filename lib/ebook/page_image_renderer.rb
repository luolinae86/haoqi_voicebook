# frozen_string_literal: true

require "fiddle/import"
require "open3"
require "pathname"
require "tmpdir"
require "zlib"

module Ebook
  class PageImageRenderer
    DEFAULT_SCALE = 2.0
    DEFAULT_RIGHT_BLEED = 32.0
    RGBA_BITMAP_INFO = 16_385
    PNG_SIGNATURE = "\x89PNG\r\n\x1a\n".b
    PDFTOCAIRO_BINARY = "pdftocairo"
    CORE_GRAPHICS_FILTER = "QuartzPageRender"
    PDFTOCAIRO_FILTER = "PdftocairoPageRender"
    RENDER_FILTERS = [CORE_GRAPHICS_FILTER, PDFTOCAIRO_FILTER].freeze

    class RenderUnavailableError < StandardError; end

    def initialize(pdf_path:, scale: DEFAULT_SCALE, backend: nil)
      @pdf_path = Pathname.new(pdf_path.to_s)
      @scale = scale.to_f
      explicit_backend = backend.to_s.strip
      env_backend = ENV["EBOOK_PDF_RENDERER_BACKEND"].to_s.strip
      @backend_preference = if !explicit_backend.empty?
                              explicit_backend
                            elsif !env_backend.empty?
                              env_backend
                            else
                              "auto"
                            end
      @provider = nil
      @document = nil
      @backend = nil
      configure_backend!
    end

    def available?
      !@backend.nil?
    end

    def render_crop(page_number:, page_width:, page_height:, bbox:, right_bleed: 0.0)
      raise RenderUnavailableError, "当前环境不支持 PDF 页面渲染" unless available?

      case @backend
      when :pdftocairo
        render_with_pdftocairo(
          page_number: page_number,
          page_width: page_width,
          page_height: page_height,
          bbox: bbox,
          right_bleed: right_bleed
        )
      when :core_graphics
        render_with_core_graphics(
          page_number: page_number,
          page_width: page_width,
          page_height: page_height,
          bbox: bbox,
          right_bleed: right_bleed
        )
      else
        raise RenderUnavailableError, "当前环境不支持 PDF 页面渲染"
      end
    end

    def close
      close_core_graphics_document
    end

    private

    def configure_backend!
      case @backend_preference
      when "auto"
        if pdftocairo_available?
          @backend = :pdftocairo
        elsif darwin_platform? && open_core_graphics_document!
          @backend = :core_graphics
        end
      when "pdftocairo"
        @backend = :pdftocairo if pdftocairo_available?
      when "core_graphics"
        @backend = :core_graphics if darwin_platform? && open_core_graphics_document!
      else
        raise ArgumentError, "未知 PDF 页面渲染后端: #{@backend_preference}"
      end
    end

    def darwin_platform?
      RUBY_PLATFORM.include?("darwin")
    end

    def pdftocairo_available?
      !pdftocairo_path.nil?
    end

    def pdftocairo_path
      @pdftocairo_path ||= ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).find do |dir|
        candidate = File.join(dir, PDFTOCAIRO_BINARY)
        File.file?(candidate) && File.executable?(candidate)
      end
    end

    def open_core_graphics_document!
      return false unless core_graphics

      @provider = core_graphics.CGDataProviderCreateWithFilename(@pdf_path.to_s)
      return false unless @provider&.to_i&.positive?

      @document = core_graphics.CGPDFDocumentCreateWithProvider(@provider)
      @document&.to_i&.positive?
    rescue Fiddle::DLError
      @provider = nil
      @document = nil
      false
    end

    def close_core_graphics_document
      return unless core_graphics

      core_graphics.CGPDFDocumentRelease(@document) if @document&.to_i&.positive?
      core_graphics.CGDataProviderRelease(@provider) if @provider&.to_i&.positive?
      @document = nil
      @provider = nil
    end

    def core_graphics
      return @core_graphics if defined?(@core_graphics)

      @core_graphics = begin
        mod = Module.new
        mod.extend(Fiddle::Importer)
        mod.dlload("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics")
        mod.typealias("size_t", "unsigned long")
        mod.typealias("CGFloat", "double")
        mod.extern("void* CGDataProviderCreateWithFilename(char*)")
        mod.extern("void  CGDataProviderRelease(void*)")
        mod.extern("void* CGPDFDocumentCreateWithProvider(void*)")
        mod.extern("void  CGPDFDocumentRelease(void*)")
        mod.extern("void* CGPDFDocumentGetPage(void*, size_t)")
        mod.extern("void* CGColorSpaceCreateDeviceRGB()")
        mod.extern("void  CGColorSpaceRelease(void*)")
        mod.extern("void* CGBitmapContextCreate(void*, size_t, size_t, size_t, size_t, void*, unsigned int)")
        mod.extern("void  CGContextTranslateCTM(void*, CGFloat, CGFloat)")
        mod.extern("void  CGContextScaleCTM(void*, CGFloat, CGFloat)")
        mod.extern("void  CGContextDrawPDFPage(void*, void*)")
        mod.extern("void  CGContextRelease(void*)")
        mod
      rescue Fiddle::DLError
        nil
      end
    end

    def render_with_pdftocairo(page_number:, page_width:, page_height:, bbox:, right_bleed: 0.0)
      crop_box = normalized_bbox(bbox, page_width.to_f, page_height.to_f, right_bleed.to_f)
      pixel_left, pixel_top, pixel_width, pixel_height = crop_pixels(crop_box, page_height.to_f)
      dpi = [(@scale * 72).round, 1].max

      Dir.mktmpdir("page-renderer") do |dir|
        prefix = File.join(dir, "page-#{page_number}")
        command = [
          pdftocairo_path,
          "-png",
          "-singlefile",
          "-r", dpi.to_s,
          "-f", page_number.to_i.to_s,
          "-l", page_number.to_i.to_s,
          "-x", pixel_left.to_s,
          "-y", pixel_top.to_s,
          "-W", pixel_width.to_s,
          "-H", pixel_height.to_s,
          @pdf_path.to_s,
          prefix
        ]
        stdout, stderr, status = Open3.capture3(*command)
        unless status.success?
          detail = [stderr, stdout].map { |value| value.to_s.strip }.find { |value| !value.empty? } || "unknown error"
          raise RenderUnavailableError, "pdftocairo 渲染失败: #{detail}"
        end

        output_path = "#{prefix}.png"
        raise RenderUnavailableError, "pdftocairo 未输出 PNG 文件: #{output_path}" unless File.exist?(output_path)

        {
          bytes: File.binread(output_path),
          extension: "png",
          mime_type: "image/png",
          image_width: pixel_width,
          image_height: pixel_height,
          filter: PDFTOCAIRO_FILTER
        }
      end
    end

    def render_with_core_graphics(page_number:, page_width:, page_height:, bbox:, right_bleed: 0.0)
      raise RenderUnavailableError, "当前环境不支持 PDF 页面渲染" unless @document&.to_i&.positive?

      right_bleed = [right_bleed.to_f, 0.0].max
      crop_box = normalized_bbox(bbox, page_width.to_f, page_height.to_f, right_bleed)
      rgba, rendered_width, rendered_height = render_page_with_core_graphics(page_number, page_width.to_f, page_height.to_f, right_bleed)
      oriented_page = flip_rgba_vertically(rgba, rendered_width, rendered_height)

      pixel_left, pixel_top, pixel_width, pixel_height = crop_pixels(crop_box, page_height.to_f)
      pixel_width = [pixel_width, rendered_width - pixel_left].min
      pixel_height = [pixel_height, rendered_height - pixel_top].min

      cropped = crop_rgba(
        rgba: oriented_page,
        source_width: rendered_width,
        left: pixel_left,
        top: pixel_top,
        width: pixel_width,
        height: pixel_height
      )

      {
        bytes: write_png(pixel_width, pixel_height, cropped),
        extension: "png",
        mime_type: "image/png",
        image_width: pixel_width,
        image_height: pixel_height,
        filter: CORE_GRAPHICS_FILTER
      }
    end

    def crop_pixels(crop_box, page_height)
      pixel_left = [(crop_box[:left] * @scale).floor, 0].max
      pixel_top = [((page_height - crop_box[:top]) * @scale).floor, 0].max
      pixel_width = [(crop_box[:width] * @scale).ceil, 1].max
      pixel_height = [(crop_box[:height] * @scale).ceil, 1].max
      [pixel_left, pixel_top, pixel_width, pixel_height]
    end

    def normalized_bbox(bbox, page_width, page_height, right_bleed = 0.0)
      extended_page_width = page_width + right_bleed.to_f
      left = [[bbox[:left].to_f, 0].max, page_width].min
      bottom = [[bbox[:bottom].to_f, 0].max, page_height].min
      right = [[bbox[:left].to_f + bbox[:width].to_f, 0].max, extended_page_width].min
      top = [[bbox[:bottom].to_f + bbox[:height].to_f, 0].max, page_height].min
      right = extended_page_width if right_bleed.positive? && right >= (page_width - 1.0)
      width = right - left
      height = top - bottom

      if width <= 1 || height <= 1
        { left: 0.0, bottom: 0.0, width: extended_page_width, height: page_height, top: page_height }
      else
        { left: left, bottom: bottom, width: width, height: height, top: top }
      end
    end

    def render_page_with_core_graphics(page_number, page_width, page_height, right_bleed = 0.0)
      page_ref = core_graphics.CGPDFDocumentGetPage(@document, page_number)
      raise RenderUnavailableError, "无法渲染 PDF 第 #{page_number} 页" unless page_ref&.to_i&.positive?

      width = [((page_width + right_bleed.to_f) * @scale).ceil, 1].max
      height = [(page_height * @scale).ceil, 1].max
      bytes_per_row = width * 4
      byte_count = bytes_per_row * height
      buffer = Fiddle::Pointer.malloc(byte_count)
      buffer[0, byte_count] = "\xFF" * byte_count

      color_space = core_graphics.CGColorSpaceCreateDeviceRGB()
      context = core_graphics.CGBitmapContextCreate(buffer, width, height, 8, bytes_per_row, color_space, RGBA_BITMAP_INFO)
      raise RenderUnavailableError, "无法创建 PDF 渲染上下文" unless context&.to_i&.positive?

      core_graphics.CGContextTranslateCTM(context, 0, height)
      core_graphics.CGContextScaleCTM(context, @scale, -@scale)
      core_graphics.CGContextDrawPDFPage(context, page_ref)

      [buffer[0, byte_count], width, height]
    ensure
      core_graphics.CGContextRelease(context) if defined?(context) && context&.to_i&.positive?
      core_graphics.CGColorSpaceRelease(color_space) if defined?(color_space) && color_space&.to_i&.positive?
    end

    def crop_rgba(rgba:, source_width:, left:, top:, width:, height:)
      row_length = source_width * 4
      cropped = +"".b

      height.times do |row|
        source_offset = ((top + row) * row_length) + (left * 4)
        cropped << rgba.byteslice(source_offset, width * 4)
      end

      cropped
    end

    def flip_rgba_vertically(rgba, width, height)
      row_size = width * 4
      flipped = +"".b

      (height - 1).downto(0) do |row|
        flipped << rgba.byteslice(row * row_size, row_size)
      end

      flipped
    end

    def write_png(width, height, rgba_data)
      rows = +"".b

      height.times do |row|
        start = row * width * 4
        rows << "\x00" << rgba_data.byteslice(start, width * 4)
      end

      compressed = Zlib::Deflate.deflate(rows)

      PNG_SIGNATURE +
        png_chunk("IHDR", [width, height, 8, 6, 0, 0, 0].pack("NNC5")) +
        png_chunk("IDAT", compressed) +
        png_chunk("IEND", +"".b)
    end

    def png_chunk(type, data)
      [data.bytesize].pack("N") + type + data + [Zlib.crc32(type + data)].pack("N")
    end
  end
end
