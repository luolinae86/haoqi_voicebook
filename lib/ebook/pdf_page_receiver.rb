# frozen_string_literal: true

require "pdf-reader"
require_relative "font_text_run"

module Ebook
  # 扩展 PDF::Reader 的文本接收器，补充图片位置信息提取
  class PdfPageReceiver < PDF::Reader::PageTextReceiver
    attr_reader :image_runs

    def page=(page)
      super
      @image_runs = []
    end

    def invoke_xobject(label)
      @state.invoke_xobject(label) do |xobject|
        case xobject
        when PDF::Reader::FormXObject
          xobject.walk(self)
        when PDF::Reader::Stream
          capture_image_xobject(label, xobject)
        end
      end
    end

    private

    def internal_show_text(string)
      PDF::Reader::Error.validate_type_as_malformed(string, "string", String)
      raise PDF::Reader::MalformedPDFError, "current font is invalid" if @state.current_font.nil?

      font = @state.current_font
      label = @state.instance_variable_get(:@stack).last[:text_font]
      font_name = font.basefont.to_s
      font_family = normalize_font_family(font_name)
      font_weight = font_name.match?(/bold|black|heavy/i) ? "bold" : "normal"
      font_style = font_name.match?(/italic|oblique/i) ? "italic" : "normal"
      glyphs = font.unpack(string)

      glyphs.each do |glyph_code|
        newx, newy = @state.trm_transform(0, 0)
        newx, newy = apply_rotation(newx, newy)

        utf8_chars = font.to_utf8(glyph_code)
        glyph_width = font.glyph_width_in_text_space(glyph_code)
        scaled_glyph_width = glyph_width * @state.font_size

        unless utf8_chars == SPACE
          @characters << FontTextRun.new(
            newx,
            newy,
            scaled_glyph_width,
            @state.font_size,
            utf8_chars,
            font_label: label.to_s,
            font_name: font_name,
            font_family: font_family,
            font_weight: font_weight,
            font_style: font_style
          )
        end

        @state.process_glyph_displacement(glyph_width, 0, utf8_chars == SPACE)
      end
    end

    def capture_image_xobject(label, xobject)
      return unless xobject.hash[:Subtype] == :Image

      corners = [
        point_from_rotation(0, 0),
        point_from_rotation(1, 0),
        point_from_rotation(0, 1),
        point_from_rotation(1, 1)
      ]

      xs = corners.map(&:x)
      ys = corners.map(&:y)

      @image_runs << {
        label: label.to_s,
        xobject: xobject,
        left: xs.min.to_f,
        bottom: ys.min.to_f,
        width: (xs.max - xs.min).to_f,
        height: (ys.max - ys.min).to_f,
        source_width: xobject.hash[:Width].to_i,
        source_height: xobject.hash[:Height].to_i,
        filter: Array(xobject.hash[:Filter]).first
      }
    end

    def normalize_font_family(font_name)
      normalized = font_name.to_s.sub(/\A[A-Z0-9]{6}\+/, "")
      normalized = normalized.split(",").first.to_s
      normalized.empty? ? "Unknown" : normalized
    end

    def point_from_transform(x, y)
      transformed_x, transformed_y = @state.ctm_transform(x, y)
      PDF::Reader::Point.new(transformed_x, transformed_y)
    end

    def point_from_rotation(x, y)
      point = point_from_transform(x, y)
      rotated_x, rotated_y = apply_rotation(point.x, point.y)
      PDF::Reader::Point.new(rotated_x, rotated_y)
    end
  end
end
