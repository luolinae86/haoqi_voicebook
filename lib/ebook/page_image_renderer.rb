# frozen_string_literal: true

require "fiddle/import"
require "pathname"
require "zlib"

module Ebook
  class PageImageRenderer
    DEFAULT_SCALE = 2.0
    DEFAULT_RIGHT_BLEED = 32.0
    RGBA_BITMAP_INFO = 16_385
    PNG_SIGNATURE = "\x89PNG\r\n\x1a\n".b

    class RenderUnavailableError < StandardError; end

    module CoreGraphics
      extend Fiddle::Importer

      dlload "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics"
      typealias "size_t", "unsigned long"
      typealias "CGFloat", "double"

      extern "void* CGDataProviderCreateWithFilename(char*)"
      extern "void  CGDataProviderRelease(void*)"
      extern "void* CGPDFDocumentCreateWithProvider(void*)"
      extern "void  CGPDFDocumentRelease(void*)"
      extern "void* CGPDFDocumentGetPage(void*, size_t)"
      extern "void* CGColorSpaceCreateDeviceRGB()"
      extern "void  CGColorSpaceRelease(void*)"
      extern "void* CGBitmapContextCreate(void*, size_t, size_t, size_t, size_t, void*, unsigned int)"
      extern "void  CGContextTranslateCTM(void*, CGFloat, CGFloat)"
      extern "void  CGContextScaleCTM(void*, CGFloat, CGFloat)"
      extern "void  CGContextDrawPDFPage(void*, void*)"
      extern "void  CGContextRelease(void*)"
    end

    def initialize(pdf_path:, scale: DEFAULT_SCALE)
      @pdf_path = Pathname.new(pdf_path.to_s)
      @scale = scale.to_f
      @provider = nil
      @document = nil
      open_document!
    end

    def available?
      @document&.to_i&.positive?
    end

    def render_crop(page_number:, page_width:, page_height:, bbox:, right_bleed: 0.0)
      raise RenderUnavailableError, "当前环境不支持 PDF 页面渲染" unless available?

      right_bleed = [right_bleed.to_f, 0.0].max
      crop_box = normalized_bbox(bbox, page_width.to_f, page_height.to_f, right_bleed)
      rgba, rendered_width, rendered_height = render_page(page_number, page_width.to_f, page_height.to_f, right_bleed)
      oriented_page = flip_rgba_vertically(rgba, rendered_width, rendered_height)

      pixel_left = [(crop_box[:left] * @scale).floor, 0].max
      pixel_top = [((page_height.to_f - crop_box[:top]) * @scale).floor, 0].max
      pixel_width = [(crop_box[:width] * @scale).ceil, 1].max
      pixel_height = [(crop_box[:height] * @scale).ceil, 1].max

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
        filter: "QuartzPageRender"
      }
    end

    def close
      CoreGraphics.CGPDFDocumentRelease(@document) if @document&.to_i&.positive?
      CoreGraphics.CGDataProviderRelease(@provider) if @provider&.to_i&.positive?
      @document = nil
      @provider = nil
    end

    private

    def open_document!
      return unless RUBY_PLATFORM.include?("darwin")

      @provider = CoreGraphics.CGDataProviderCreateWithFilename(@pdf_path.to_s)
      return unless @provider&.to_i&.positive?

      @document = CoreGraphics.CGPDFDocumentCreateWithProvider(@provider)
    rescue Fiddle::DLError
      @provider = nil
      @document = nil
    end

    def normalized_bbox(bbox, page_width, page_height, right_bleed = 0.0)
      extended_page_width = page_width + right_bleed.to_f
      left = [[bbox[:left].to_f, 0].max, page_width].min
      bottom = [[bbox[:bottom].to_f, 0].max, page_height].min
      right = [[bbox[:left].to_f + bbox[:width].to_f, 0].max, extended_page_width].min
      top = [[bbox[:bottom].to_f + bbox[:height].to_f, 0].max, page_height].min
      if right_bleed.positive? && right >= (page_width - 1.0)
        right = extended_page_width
      end
      width = right - left
      height = top - bottom

      if width <= 1 || height <= 1
        { left: 0.0, bottom: 0.0, width: extended_page_width, height: page_height, top: page_height }
      else
        { left: left, bottom: bottom, width: width, height: height, top: top }
      end
    end

    def render_page(page_number, page_width, page_height, right_bleed = 0.0)
      page_ref = CoreGraphics.CGPDFDocumentGetPage(@document, page_number)
      raise RenderUnavailableError, "无法渲染 PDF 第 #{page_number} 页" unless page_ref&.to_i&.positive?

      width = [((page_width + right_bleed.to_f) * @scale).ceil, 1].max
      height = [(page_height * @scale).ceil, 1].max
      bytes_per_row = width * 4
      byte_count = bytes_per_row * height
      buffer = Fiddle::Pointer.malloc(byte_count)
      buffer[0, byte_count] = "\xFF" * byte_count

      color_space = CoreGraphics.CGColorSpaceCreateDeviceRGB()
      context = CoreGraphics.CGBitmapContextCreate(buffer, width, height, 8, bytes_per_row, color_space, RGBA_BITMAP_INFO)
      raise RenderUnavailableError, "无法创建 PDF 渲染上下文" unless context&.to_i&.positive?

      CoreGraphics.CGContextTranslateCTM(context, 0, height)
      CoreGraphics.CGContextScaleCTM(context, @scale, -@scale)
      CoreGraphics.CGContextDrawPDFPage(context, page_ref)

      [buffer[0, byte_count], width, height]
    ensure
      CoreGraphics.CGContextRelease(context) if defined?(context) && context&.to_i&.positive?
      CoreGraphics.CGColorSpaceRelease(color_space) if defined?(color_space) && color_space&.to_i&.positive?
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
