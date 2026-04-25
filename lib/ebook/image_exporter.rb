# frozen_string_literal: true

require "fileutils"
require "pathname"
require "zlib"

module Ebook
  # 导出 PDF 内嵌图片，并生成可直接返回给前端的 URL
  class ImageExporter
    class UnsupportedImageError < StandardError; end

    PNG_SIGNATURE = "\x89PNG\r\n\x1a\n".b

    def initialize(objects:, public_root:, storage_root:)
      @objects = objects
      @public_root = Pathname.new(public_root.to_s)
      @storage_root = Pathname.new(storage_root.to_s)
    end

    def export(xobject:, page_number:, image_number:)
      FileUtils.mkdir_p(@storage_root.join("page_#{page_number}"))

      extension, mime_type, bytes = serialized_image(xobject)
      write_export(
        page_number: page_number,
        image_number: image_number,
        extension: extension,
        mime_type: mime_type,
        bytes: bytes,
        image_width: xobject.hash[:Width].to_i,
        image_height: xobject.hash[:Height].to_i,
        filter: Array(xobject.hash[:Filter]).first.to_s
      )
    end

    def export_rendered(rendered:, page_number:, image_number:)
      write_export(
        page_number: page_number,
        image_number: image_number,
        extension: rendered.fetch(:extension),
        mime_type: rendered.fetch(:mime_type),
        bytes: rendered.fetch(:bytes),
        image_width: rendered.fetch(:image_width),
        image_height: rendered.fetch(:image_height),
        filter: rendered.fetch(:filter)
      )
    end

    private

    def write_export(page_number:, image_number:, extension:, mime_type:, bytes:, image_width:, image_height:, filter:)
      filename = "image_#{image_number}.#{extension}"
      output_path = @storage_root.join("page_#{page_number}", filename)

      FileUtils.mkdir_p(output_path.dirname)
      File.binwrite(output_path, bytes)

      {
        image_url: public_url_for(output_path),
        storage_path: output_path.to_s,
        mime_type: mime_type,
        image_width: image_width,
        image_height: image_height,
        filter: filter.to_s
      }
    end

    def serialized_image(xobject)
      case Array(xobject.hash[:Filter]).first
      when :DCTDecode
        ["jpg", "image/jpeg", xobject.data]
      when :JPXDecode
        ["jpx", "image/jpx", xobject.data]
      when :CCITTFaxDecode, :JBIG2Decode
        raise UnsupportedImageError, "暂不支持导出 #{Array(xobject.hash[:Filter]).first} 图片"
      else
        ["png", "image/png", build_png(xobject)]
      end
    end

    def build_png(xobject)
      width = xobject.hash[:Width].to_i
      height = xobject.hash[:Height].to_i
      bits = (xobject.hash[:BitsPerComponent] || 8).to_i
      raise UnsupportedImageError, "仅支持 8-bit 图片导出" unless bits == 8

      color_space = resolve_color_space(xobject.hash[:ColorSpace])
      pixel_data = xobject.unfiltered_data
      alpha_data = resolve_soft_mask(xobject.hash[:SMask], width, height)
      rgba_data = decode_pixels(pixel_data, color_space, width, height, alpha_data)

      write_png(width, height, rgba_data)
    end

    def resolve_color_space(raw_value)
      value = dereference(raw_value)
      return :DeviceGray if value.nil?

      if value.is_a?(Array)
        value.map { |item| dereference(item) }
      else
        value
      end
    end

    def resolve_soft_mask(mask, width, height)
      stream = dereference(mask)
      return unless stream.is_a?(PDF::Reader::Stream)
      return unless stream.hash[:Width].to_i == width && stream.hash[:Height].to_i == height
      return unless (stream.hash[:BitsPerComponent] || 8).to_i == 8

      stream.unfiltered_data
    end

    def decode_pixels(pixel_data, color_space, width, height, alpha_data)
      rgba = +"".b
      pixel_count = width * height

      case color_space
      when :DeviceGray
        raise UnsupportedImageError, "灰度图数据长度异常" if pixel_data.bytesize < pixel_count

        pixel_count.times do |index|
          gray = pixel_data.getbyte(index)
          alpha = alpha_data ? alpha_data.getbyte(index) : 255
          rgba << gray.chr << gray.chr << gray.chr << alpha.chr
        end
      when :DeviceRGB
        raise UnsupportedImageError, "RGB 图数据长度异常" if pixel_data.bytesize < pixel_count * 3

        pixel_count.times do |index|
          offset = index * 3
          alpha = alpha_data ? alpha_data.getbyte(index) : 255
          rgba << pixel_data.byteslice(offset, 3) << alpha.chr
        end
      when :DeviceCMYK
        raise UnsupportedImageError, "CMYK 图数据长度异常" if pixel_data.bytesize < pixel_count * 4

        pixel_count.times do |index|
          offset = index * 4
          c = pixel_data.getbyte(offset)
          m = pixel_data.getbyte(offset + 1)
          y = pixel_data.getbyte(offset + 2)
          k = pixel_data.getbyte(offset + 3)
          alpha = alpha_data ? alpha_data.getbyte(index) : 255

          rgba << cmyk_to_rgb(c, m, y, k).pack("C3") << alpha.chr
        end
      when Array
        decode_indexed_pixels(pixel_data, color_space, pixel_count, alpha_data, rgba)
      else
        raise UnsupportedImageError, "暂不支持的色彩空间: #{color_space.inspect}"
      end

      rgba
    end

    def decode_indexed_pixels(pixel_data, color_space, pixel_count, alpha_data, rgba)
      raise UnsupportedImageError, "暂不支持的索引色彩空间: #{color_space.inspect}" unless color_space.first == :Indexed

      base_color_space = dereference(color_space[1])
      palette_data = dereference(color_space[3])
      palette = palette_bytes(palette_data)
      components = base_color_space == :DeviceGray ? 1 : 3

      raise UnsupportedImageError, "暂不支持的索引色彩空间: #{base_color_space.inspect}" unless %i[DeviceGray DeviceRGB].include?(base_color_space)

      pixel_count.times do |index|
        palette_index = pixel_data.getbyte(index).to_i * components
        alpha = alpha_data ? alpha_data.getbyte(index) : 255

        if base_color_space == :DeviceGray
          gray = palette.getbyte(palette_index)
          rgba << gray.chr << gray.chr << gray.chr << alpha.chr
        else
          rgba << palette.byteslice(palette_index, 3) << alpha.chr
        end
      end
    end

    def palette_bytes(palette_data)
      case palette_data
      when PDF::Reader::Stream
        palette_data.unfiltered_data
      when String
        palette_data
      else
        raise UnsupportedImageError, "无法读取索引色调色板"
      end
    end

    def cmyk_to_rgb(cyan, magenta, yellow, black)
      c = cyan / 255.0
      m = magenta / 255.0
      y = yellow / 255.0
      k = black / 255.0

      [
        ((1 - c) * (1 - k) * 255).round.clamp(0, 255),
        ((1 - m) * (1 - k) * 255).round.clamp(0, 255),
        ((1 - y) * (1 - k) * 255).round.clamp(0, 255)
      ]
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

    def public_url_for(path)
      relative_path = path.relative_path_from(@public_root).to_s
      "/#{relative_path.tr(File::SEPARATOR, '/')}"
    rescue ArgumentError
      path.to_s
    end

    def dereference(value)
      return value unless defined?(PDF::Reader::Reference) && value.is_a?(PDF::Reader::Reference)

      @objects[value]
    end
  end
end
