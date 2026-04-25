# frozen_string_literal: true

require "base64"
require "prawn"
require "tempfile"

module PdfFixtureHelper
  SAMPLE_PNG = <<~BASE64.delete("\n")
    iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO9W4l8AAAAASUVORK5CYII=
  BASE64

  def create_sample_ebook_pdf
    pdf_file = Tempfile.new(%w[sample-ebook .pdf])
    image_file = Tempfile.new(%w[sample-image .png])
    image_file.binmode
    image_file.write(Base64.decode64(SAMPLE_PNG))
    image_file.flush

    Prawn::Document.generate(pdf_file.path, margin: 48) do |pdf|
      pdf.font_size 24
      pdf.text "Chapter 1 Luminous Badge", align: :center
      pdf.move_down 18
      pdf.font_size 12
      pdf.text "This is the first page body content for importer verification."
      pdf.move_down 10
      pdf.text "The second paragraph helps verify structured rich text reconstruction."
      pdf.image image_file.path, at: [180, 520], width: 90
      pdf.image image_file.path, at: [500, 340], width: 36

      pdf.start_new_page
      pdf.font_size 20
      pdf.text "Second Page Title"
      pdf.move_down 16
      pdf.font_size 12
      pdf.text "The second page content should be readable page by page with navigation data."
    end

    { pdf: pdf_file, image: image_file }
  end

  def cleanup_sample_ebook_pdf(files)
    return if files.blank?

    files.values.each do |file|
      file.close!
    rescue Errno::ENOENT
      nil
    end
  end
end

RSpec.configure do |config|
  config.include PdfFixtureHelper
end
