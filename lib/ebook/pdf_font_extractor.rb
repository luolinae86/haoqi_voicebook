# frozen_string_literal: true

require "digest"
require "pathname"
require "pdf-reader"

module Ebook
  class PdfFontExtractor
    FONT_FILE_FORMATS = {
      FontFile: {
        ext: ".pfb",
        media_type: "application/x-font-type1",
        format: "type1"
      },
      FontFile2: {
        ext: ".ttf",
        media_type: "font/ttf",
        format: "truetype"
      }
    }.freeze

    def initialize(pdf_path:)
      @pdf_path = Pathname.new(pdf_path.to_s)
    end

    def call(used_font_names:, used_font_families:)
      return [] unless @pdf_path.exist?

      wanted_tokens = font_tokens(used_font_names) + font_tokens(used_font_families)
      wanted_tokens = wanted_tokens.compact_blank.uniq
      return [] if wanted_tokens.empty?

      reader = PDF::Reader.new(@pdf_path.to_s)
      extracted = {}

      reader.pages.each do |page|
        each_embedded_font(page) do |basefont:, normalized_name:, descriptor:|
          aliases = [basefont, normalized_name].flat_map { |name| font_tokens([name]) }.uniq
          next if (aliases & wanted_tokens).empty?
          next if extracted.key?(basefont)

          font_asset = build_font_asset(page, descriptor, basefont, normalized_name, aliases)
          extracted[basefont] = font_asset if font_asset.present?
        end
      end

      extracted.values
    end

    private

    def each_embedded_font(page)
      resources_ref = page.attributes[:Resources]
      return unless resources_ref

      resources = page.objects.deref_hash(resources_ref)
      return unless resources.is_a?(Hash) && resources[:Font]

      font_dict = page.objects.deref_hash(resources[:Font]) || {}
      font_dict.each_value do |font_ref|
        font = page.objects.deref_hash(font_ref)
        next unless font.is_a?(Hash)

        descendant_ref = page.objects.deref_array(font[:DescendantFonts])&.first if font[:DescendantFonts]
        descendant = page.objects.deref_hash(descendant_ref) if descendant_ref
        descriptor_ref = font[:FontDescriptor] || descendant&.[](:FontDescriptor)
        descriptor = page.objects.deref_hash(descriptor_ref) if descriptor_ref
        next unless descriptor.is_a?(Hash)

        basefont = (font[:BaseFont] || descendant&.[](:BaseFont)).to_s
        next if basefont.blank?

        embedded_key = [:FontFile, :FontFile2, :FontFile3].find { |key| descriptor[key] }
        next unless embedded_key

        yield(
          basefont: basefont,
          normalized_name: normalize_font_name(basefont),
          descriptor: descriptor
        )
      end
    end

    def build_font_asset(page, descriptor, basefont, normalized_name, aliases)
      embedded_key = [:FontFile, :FontFile2, :FontFile3].find { |key| descriptor[key] }
      return unless embedded_key

      stream = page.objects.deref_stream(descriptor[embedded_key])
      return unless stream.respond_to?(:data) && stream.data.present?

      format = font_format_for(embedded_key, stream)
      return unless format

      digest = Digest::SHA256.hexdigest("#{basefont}-#{stream.data.bytesize}")
      {
        source_name: basefont,
        normalized_name: normalized_name,
        css_family: css_family_for(normalized_name, digest),
        filename: "font-#{digest[0, 16]}#{format[:ext]}",
        media_type: format[:media_type],
        format: format[:format],
        data: stream.data,
        aliases: aliases
      }
    end

    def font_format_for(embedded_key, stream)
      return FONT_FILE_FORMATS[embedded_key] if FONT_FILE_FORMATS.key?(embedded_key)
      return unless embedded_key == :FontFile3

      subtype = stream.hash[:Subtype].to_s
      case subtype
      when "OpenType"
        { ext: ".otf", media_type: "font/otf", format: "opentype" }
      when "CIDFontType0C", "Type1C"
        { ext: ".cff", media_type: "application/font-sfnt", format: "opentype" }
      end
    end

    def css_family_for(normalized_name, digest)
      sanitized = normalized_name.to_s.gsub(/[^A-Za-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
      sanitized = "pdf-font" if sanitized.blank?
      "PDFEmbed-#{sanitized[0, 24]}-#{digest[0, 8]}"
    end

    def font_tokens(values)
      Array(values).flat_map do |value|
        token = value.to_s.strip
        next [] if token.blank?

        normalized = normalize_font_name(token)
        [token, normalized].compact_blank.uniq
      end
    end

    def normalize_font_name(font_name)
      normalized = font_name.to_s.sub(/\A[A-Z0-9]{6}\+/, "")
      normalized = normalized.split(",").first.to_s
      normalized.strip
    end
  end
end
