# frozen_string_literal: true

task :check_epub_pages => :environment do
  require "tmpdir"
  require "zip"

  book = Book.find(11)
  epub_oss_key = (book.content_file_url || book.file_url).sub(%r{https?://[^/]+/}, "")

  Dir.mktmpdir do |dir|
    path = File.join(dir, "book.epub")
    AliyunOssService.new.download_file(object_key: epub_oss_key, local_path: path)

    Zip::File.open(path) do |zip|
      zip.each do |entry|
        next unless entry.name.end_with?("toc.ncx")
        puts "=== #{entry.name} ==="
        xml = Nokogiri::XML(entry.get_input_stream.read)

        page_targets = xml.xpath("//ncx:pageList//ncx:pageTarget", "ncx" => "http://www.daisy.org/z3986/2005/ncx/")
        if page_targets.any?
          page_targets.each do |pt|
            name = pt["name"] || pt["playOrder"]
            src = pt.at_xpath("ncx:content", "ncx" => "http://www.daisy.org/z3986/2005/ncx/")&.[]("src")
            text = pt.at_xpath("ncx:navLabel/ncx:text", "ncx" => "http://www.daisy.org/z3986/2005/ncx/")&.text
            puts "  pageTarget: name=#{name} text=#{text} src=#{src}"
          end
        else
          puts "  No page-list found"
        end

        puts "  Total navPoints: #{xml.xpath('//ncx:navPoint', 'ncx' => 'http://www.daisy.org/z3986/2005/ncx/').count}"
      end
    end
  end
end
