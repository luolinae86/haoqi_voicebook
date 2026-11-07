# frozen_string_literal: true

require "rails_helper"
require "tempfile"

RSpec.describe AliyunOssService do
  let(:mock_bucket) { instance_double(Aliyun::OSS::Bucket) }
  let(:oss_service) { described_class.new(bucket: mock_bucket) }

  describe ".key_from_url" do
    # 外部（hao_qi_read）传进来的直链里，文件名是百分号编码的，而 SDK 只认原始键
    it "decodes a percent-encoded object key" do
      expect(described_class.key_from_url("https://bucket.oss-cn-beijing.aliyuncs.com/books/61355/%E5%A5%B3%E5%A8%B2%E8%A1%A5%E5%A4%A9.zip"))
        .to eq("books/61355/女娲补天.zip")
    end

    it "accepts a URL whose path is not encoded, which URI.parse would reject" do
      expect { URI.parse("https://h.oss/女娲.zip") }.to raise_error(URI::InvalidURIError)
      expect(described_class.key_from_url("https://h.oss/女娲.zip")).to eq("女娲.zip")
    end

    it "drops the query of a signed URL" do
      expect(described_class.key_from_url("https://h.oss/a.zip?Expires=1&OSSAccessKeyId=k&Signature=s%2Fz"))
        .to eq("a.zip")
    end

    it "keeps a literal plus, unlike CGI.unescape which turns it into a space" do
      expect(described_class.key_from_url("https://h.oss/a+b.zip")).to eq("a+b.zip")
    end

    it "unescapes in a single pass, so %25 becomes a literal percent" do
      expect(described_class.key_from_url("https://h.oss/100%25.zip")).to eq("100%.zip")
    end

    it "passes through something that is already an object key" do
      expect(described_class.key_from_url("books/61355/package.zip")).to eq("books/61355/package.zip")
    end

    it "returns blank when the URL has no path" do
      expect(described_class.key_from_url("https://h.oss")).to eq("")
      expect(described_class.key_from_url("")).to eq("")
      expect(described_class.key_from_url(nil)).to eq("")
    end
  end

  describe "#upload_file" do
    it "uploads a local file and returns the public URL" do
      tempfile = Tempfile.new(["test", ".png"])
      tempfile.write("fake image data")
      tempfile.flush

      allow(mock_bucket).to receive(:put_object)
      allow(oss_service).to receive(:public_url).with("images/test.png").and_return("https://epub-files.oss-cn-beijing.aliyuncs.com/images/test.png")

      result = oss_service.upload_file(
        local_path: tempfile.path,
        object_key: "images/test.png",
        content_type: "image/png"
      )

      expect(result).to eq("https://epub-files.oss-cn-beijing.aliyuncs.com/images/test.png")
      expect(mock_bucket).to have_received(:put_object).with(
        "images/test.png",
        file: tempfile.path,
        content_type: "image/png"
      )

      tempfile.close!
    end

    it "raises UploadError when local file does not exist" do
      expect do
        oss_service.upload_file(
          local_path: "/nonexistent/file.png",
          object_key: "images/missing.png"
        )
      end.to raise_error(AliyunOssService::UploadError, /OSS 上传失败/)
    end

    it "infers content type from filename when not provided" do
      tempfile = Tempfile.new(["test", ".png"])
      tempfile.write("data")
      tempfile.flush

      allow(mock_bucket).to receive(:put_object)
      allow(oss_service).to receive(:public_url).and_return("https://example.com/test.png")

      oss_service.upload_file(local_path: tempfile.path, object_key: "images/test.png")

      expect(mock_bucket).to have_received(:put_object).with(
        "images/test.png",
        file: tempfile.path,
        content_type: "image/png"
      )

      tempfile.close!
    end
  end

  describe "#upload_data" do
    it "uploads binary data and returns the public URL" do
      data = "\x89PNG\r\n\x1a\n" # fake PNG header
      allow(mock_bucket).to receive(:put_object).and_yield(StringIO.new)
      allow(oss_service).to receive(:public_url).with("pages/1/image.png").and_return("https://epub-files.oss-cn-beijing.aliyuncs.com/pages/1/image.png")

      result = oss_service.upload_data(
        data: data,
        object_key: "pages/1/image.png",
        content_type: "image/png"
      )

      expect(result).to eq("https://epub-files.oss-cn-beijing.aliyuncs.com/pages/1/image.png")
      expect(mock_bucket).to have_received(:put_object).with(
        "pages/1/image.png",
        content_type: "image/png"
      )
    end
  end

  describe "#download_file" do
    it "downloads a file from OSS to local path" do
      dir = Dir.mktmpdir
      local_path = File.join(dir, "downloaded.pdf")

      allow(mock_bucket).to receive(:get_object)

      oss_service.download_file(
        object_key: "pdfs/source.pdf",
        local_path: local_path
      )

      expect(mock_bucket).to have_received(:get_object).with(
        "pdfs/source.pdf",
        file: local_path
      )

      FileUtils.rm_rf(dir)
    end
  end

  describe "#public_url" do
    it "generates a URL using the configured bucket and endpoint" do
      url = oss_service.public_url("epub-assets/books/1/book.epub")
      expect(url).to eq("https://epub-files.oss-cn-beijing.aliyuncs.com/epub-assets/books/1/book.epub")
    end
  end
end
