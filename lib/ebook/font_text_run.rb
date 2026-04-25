# frozen_string_literal: true

module Ebook
  class FontTextRun < PDF::Reader::TextRun
    attr_reader :font_label, :font_name, :font_family, :font_weight, :font_style

    def initialize(x, y, width, font_size, text, font_label:, font_name:, font_family:, font_weight:, font_style:)
      super(x, y, width, font_size, text)
      @font_label = font_label
      @font_name = font_name
      @font_family = font_family
      @font_weight = font_weight
      @font_style = font_style
    end

    def mergable?(other)
      super && same_font?(other)
    end

    def +(other)
      raise ArgumentError, "#{other} cannot be merged with this run" unless mergable?(other)

      merged_text = if (other.x - endx) < (font_size * 0.2)
                      text + other.text
                    else
                      "#{text} #{other.text}"
                    end

      self.class.new(
        x,
        y,
        other.endx - x,
        font_size,
        merged_text,
        font_label: font_label,
        font_name: font_name,
        font_family: font_family,
        font_weight: font_weight,
        font_style: font_style
      )
    end

    private

    def same_font?(other)
      other.respond_to?(:font_label) &&
        other.font_label == font_label &&
        other.font_name == font_name &&
        other.font_family == font_family &&
        other.font_weight == font_weight &&
        other.font_style == font_style
    end
  end
end
