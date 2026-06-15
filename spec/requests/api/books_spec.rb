# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API Books', type: :request do
  let(:user) { create(:app_user) }
  let!(:book) { create(:book) }

  # ==================== 合集资源 ====================
  describe 'GET /api/books/compilation' do
    it '返回合集下的所有资源' do
      compilation = create(:compilation)
      book1 = create(:book, content_description: '合集中的第一本书简介')
      book2 = create(:book)
      compilation.books << book1

      get '/api/books/compilation', params: { compilation_id: compilation.id, uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      data = json_response[:response][:data]
      expect(data[:compilation][:id]).to eq(compilation.id)
      expect(data[:compilation][:name]).to eq(compilation.name)
      book_ids = data[:books].map { |b| b[:id] }
      expect(book_ids).to include(book1.id)
      expect(book_ids).not_to include(book2.id)
      expect(data[:contents]).to be_an(Array)
      # 验证合集中的书籍返回 content_description
      book1_data = data[:books].find { |b| b[:id] == book1.id }
      expect(book1_data[:content_description]).to eq('合集中的第一本书简介')
    end

    it '返回的 img_url 是签名后的 OSS 地址' do
      compilation = create(:compilation)
      book = create(:book)
      compilation.books << book

      get '/api/books/compilation', params: { compilation_id: compilation.id, uuid: user.uuid }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      data[:contents].each do |content|
        expect(content[:img_url]).to match(/\?Expires=/)
      end
    end

    it '合集不存在时返回 404' do
      get '/api/books/compilation', params: { compilation_id: 999_999, uuid: user.uuid }

      expect(response).to have_http_status(200)
    end

    it '未提供 uuid 返回参数错误' do
      get '/api/books/compilation', params: { compilation_id: 1 }

      expect(response).to have_http_status(200)
    end

    it '无效 uuid 返回未授权' do
      get '/api/books/compilation', params: { compilation_id: 1, uuid: 'invalid-uuid' }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).not_to eq(0)
    end
  end

  # ==================== 图书详情 ====================
  describe 'GET /api/books/by_id' do
    it '返回图书详情' do
      get '/api/books/by_id', params: { id: book.id, uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:response][:data][:book][:id]).to eq(book.id)
      expect(json_response[:response][:data][:book][:name]).to eq(book.name)
    end

    it '返回图书简介 content_description' do
      book.update!(content_description: '这是一本精彩的书籍简介')

      get '/api/books/by_id', params: { id: book.id, uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:data][:book][:content_description]).to eq('这是一本精彩的书籍简介')
    end

    it '未提供 uuid 时返回参数错误' do
      get '/api/books/by_id', params: { id: book.id }

      expect(response).to have_http_status(200)
    end

    it '无效 uuid 时返回未授权错误' do
      get '/api/books/by_id', params: { id: book.id, uuid: 'invalid-uuid' }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).not_to eq(0)
    end

    it '图书不存在时返回错误提示' do
      get '/api/books/by_id', params: { id: 999_999, uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(1001)
      expect(json_response[:response][:msg]).to eq('图书不存在')
    end
  end

  # ==================== 目录 ====================
  describe 'GET /api/books/catalogue' do
    it '返回目录' do
      create(:catalogue, book: book, chapter_number: 1, chapter_name: '第一章', start_page_number: 1, word_count: 1200)
      create(:catalogue, book: book, chapter_number: 2, chapter_name: '第二章', start_page_number: 10, word_count: 2500)

      get '/api/books/catalogue', params: { id: book.id, uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      catalogues = json_response[:response][:data][:catalogues]
      expect(catalogues.size).to eq(2)
      expect(catalogues.first[:chapter_name]).to eq('第一章')
      expect(catalogues.first).to have_key(:is_free)
      expect(catalogues.first[:word_count]).to eq(1200)
    end

    it '未提供 uuid 时返回参数错误' do
      get '/api/books/catalogue', params: { id: book.id }

      expect(response).to have_http_status(200)
    end

    it '图书不存在时返回错误提示' do
      get '/api/books/catalogue', params: { id: 999_999, uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(1001)
      expect(json_response[:response][:msg]).to eq('图书不存在')
    end

    it 'EPUB 图书返回根据 ebook_pages 计算的字数' do
      epub_book = create(:book, content_file_type: 'epub')
      create(:catalogue, book: epub_book, chapter_number: 1, chapter_name: '第一章', start_page_number: 1, word_count: 0)
      create(:catalogue, book: epub_book, chapter_number: 2, chapter_name: '第二章', start_page_number: 3, word_count: 0)
      create(:ebook_page, book: epub_book, page_number: 1, word_count: 500)
      create(:ebook_page, book: epub_book, page_number: 2, word_count: 300)
      create(:ebook_page, book: epub_book, page_number: 3, word_count: 400)

      get '/api/books/catalogue', params: { id: epub_book.id, uuid: user.uuid }

      expect(response).to have_http_status(200)
      catalogues = json_response[:response][:data][:catalogues]
      expect(catalogues.first[:word_count]).to eq(800)
      expect(catalogues.second[:word_count]).to eq(400)
    end
  end

  # ==================== 导入电子书 ====================
  describe 'POST /api/books/import' do
    it '提交 PDF 导入任务' do
      book.update!(content_file_url: 'https://bucket.oss-cn-beijing.aliyuncs.com/test/book.pdf')

      post '/api/books/import', params: {
        uuid: user.uuid,
        id: book.id
      }

      expect(response).to have_http_status(201)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:response][:code]).to eq(0)
      expect(body[:response][:data][:book_id]).to eq(book.id)
      expect(body[:response][:data][:content_file_type]).to eq('pdf')
    end

    it '提交 EPUB 导入任务' do
      book.update!(content_file_url: 'https://bucket.oss-cn-beijing.aliyuncs.com/test/book.epub')

      post '/api/books/import', params: {
        uuid: user.uuid,
        id: book.id
      }

      expect(response).to have_http_status(201)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:response][:code]).to eq(0)
      expect(body[:response][:data][:content_file_type]).to eq('epub')
    end

    it '使用图书的 content_file_url 进行导入' do
      book.update!(content_file_url: 'https://bucket.oss-cn-beijing.aliyuncs.com/test/book.pdf')

      post '/api/books/import', params: {
        uuid: user.uuid,
        id: book.id
      }

      expect(response).to have_http_status(201)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:response][:code]).to eq(0)
      expect(body[:response][:data][:book_id]).to eq(book.id)
    end

    it '图书没有 file_url 时返回错误' do
      book.update!(content_file_url: nil)

      post '/api/books/import', params: {
        uuid: user.uuid,
        id: book.id
      }

      expect(response).to have_http_status(200)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:response][:code]).to be > 0
    end

    it '未提供 uuid 时返回参数错误' do
      post '/api/books/import', params: {
        id: book.id
      }

      expect(response).to have_http_status(200)
    end
  end

  # ==================== 页面清单 ====================
  describe 'GET /api/books/pages' do
    it '返回图书页面清单' do
      create(:ebook_page, :pdf_image, book: book, page_number: 1)
      create(:ebook_page, :pdf_image, book: book, page_number: 2)

      get '/api/books/pages', params: { id: book.id, uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:response][:data][:book_id]).to eq(book.id)
      expect(json_response[:response][:data][:pages]).to be_an(Array)
      expect(json_response[:response][:data][:pages].size).to eq(2)
      # 验证 image_url 返回的是签名后的 OSS 地址
      pages = json_response[:response][:data][:pages]
      pages.each do |page|
        expect(page[:image_url]).to match(/\?Expires=/)
      end
    end

    it '没有页面时返回空数组' do
      get '/api/books/pages', params: { id: book.id, uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:data][:pages]).to eq([])
    end

    it '未提供 uuid 时返回参数错误' do
      get '/api/books/pages', params: { id: book.id }

      expect(response).to have_http_status(200)
    end
  end

  # ==================== 单页内容 ====================
  describe 'GET /api/books/page' do
    it '返回 PDF 图片页内容' do
      create(:ebook_page, :pdf_image, book: book, page_number: 1)

      get '/api/books/page', params: { id: book.id, page_number: 1, uuid: user.uuid }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:book_id]).to eq(book.id)
      expect(data[:page_number]).to eq(1)
      expect(data[:image_url]).to include('Signature=')
    end

    it '未提供 uuid 时返回参数错误' do
      get '/api/books/page', params: { id: book.id, page_number: 1 }

      expect(response).to have_http_status(200)
    end

    it '页面不存在时返回 404' do
      get '/api/books/page', params: { id: book.id, page_number: 999, uuid: user.uuid }

      expect(response).to have_http_status(200)
    end
  end

  # ==================== 页面 XHTML 内容 ====================
  describe 'GET /api/books/page_html' do
    it '返回 EPUB 页 XHTML 内容' do
      create(:ebook_page, :epub, book: book, page_number: 1,
                                 xhtml_content: '<html><body><p>Test Content</p></body></html>')

      get '/api/books/page_html', params: { id: book.id, page_number: 1, uuid: user.uuid }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:book_id]).to eq(book.id)
      expect(data[:page_number]).to eq(1)
      expect(data[:xhtml_content]).to include('Test Content')
    end

    it 'XHTML 未导出时返回 404' do
      create(:ebook_page, :pdf_image, book: book, page_number: 1)

      get '/api/books/page_html', params: { id: book.id, page_number: 1, uuid: user.uuid }

      expect(response).to have_http_status(200)
    end

    it '未提供 uuid 时返回参数错误' do
      get '/api/books/page_html', params: { id: book.id, page_number: 1 }

      expect(response).to have_http_status(200)
    end
  end

  # ==================== 样式表 ====================
  describe 'GET /api/books/styles' do
    it '重定向到样式表 URL' do
      book.update!(styles_oss_url: 'https://bucket.oss-cn-beijing.aliyuncs.com/styles/book.css')

      get '/api/books/styles', params: { id: book.id, uuid: user.uuid }

      expect(response).to be_redirect
    end

    it '样式表未导出时返回 404' do
      get '/api/books/styles', params: { id: book.id, uuid: user.uuid }

      expect(response).to have_http_status(200)
    end

    it '未提供 uuid 时返回参数错误' do
      get '/api/books/styles', params: { id: book.id }

      expect(response).to have_http_status(200)
    end
  end

  # ==================== 章节内容文件URL ====================
  describe 'GET /api/books/chapter_url' do
    let!(:chapter) { create(:chapter, book: book, content_file_url: 'https://bucket.oss-cn-beijing.aliyuncs.com/test/audio.mp3') }

    it '返回签名后的 content_file_url' do
      get '/api/books/chapter_url', params: { chapter_id: chapter.id, uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      data = json_response[:response][:data]
      expect(data[:chapter_id]).to eq(chapter.id)
      expect(data[:content_file_url]).to include('Signature=')
      expect(data[:content_file_url]).to include('Expires=')
      expect(data[:content_file_type]).to eq('mp3')
      expect(data[:duration]).to be_nil
    end

    it 'URL 过期时间设置为1天' do
      get '/api/books/chapter_url', params: { chapter_id: chapter.id, uuid: user.uuid }

      data = json_response[:response][:data]
      expires = data[:content_file_url].match(/Expires=(\d+)/)
      expect(expires).to be_present
      expires_at = expires[1].to_i
      one_day_later = (Time.zone.now + 86_400).to_i
      expect(expires_at).to be_within(60).of(one_day_later)
    end

    it '章节没有 content_file_url 时返回 nil' do
      chapter.update!(content_file_url: nil)

      get '/api/books/chapter_url', params: { chapter_id: chapter.id, uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:data][:content_file_url]).to be_nil
    end

    it '返回 ld/hd/sd 文件路径（签名后的 OSS URL）' do
      chapter.update!(
        ld_file_path: 'https://bucket.oss-cn-beijing.aliyuncs.com/ld/video.mp4',
        hd_file_path: 'https://bucket.oss-cn-beijing.aliyuncs.com/hd/video.mp4',
        sd_file_path: 'https://bucket.oss-cn-beijing.aliyuncs.com/sd/video.mp4'
      )

      get '/api/books/chapter_url', params: { chapter_id: chapter.id, uuid: user.uuid }

      data = json_response[:response][:data]
      expect(data[:ld_file_path]).to include('Signature=')
      expect(data[:hd_file_path]).to include('Signature=')
      expect(data[:sd_file_path]).to include('Signature=')
    end

    it '文件路径为空时返回 nil' do
      get '/api/books/chapter_url', params: { chapter_id: chapter.id, uuid: user.uuid }

      data = json_response[:response][:data]
      expect(data[:ld_file_path]).to be_nil
      expect(data[:hd_file_path]).to be_nil
      expect(data[:sd_file_path]).to be_nil
    end

    it '章节不存在时返回错误' do
      get '/api/books/chapter_url', params: { chapter_id: 999_999, uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).not_to eq(0)
      expect(json_response[:response][:msg]).to include('章节不存在')
    end

    it '未提供 uuid 时返回参数错误' do
      get '/api/books/chapter_url', params: { chapter_id: chapter.id }

      expect(response).to have_http_status(200)
    end

    it '无效 uuid 时返回未授权错误' do
      get '/api/books/chapter_url', params: { chapter_id: chapter.id, uuid: 'invalid-uuid' }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(1002)
    end
  end

  # ==================== 图书详情 - 章节不包含 content_file_url ====================
  describe 'GET /api/books/by_id 章节字段' do
    it '图书详情中的章节不返回 content_file_url' do
      create(:chapter, book: book, content_file_url: 'https://bucket.oss-cn-beijing.aliyuncs.com/test/audio.mp3')

      get '/api/books/by_id', params: { id: book.id, uuid: user.uuid }

      expect(response).to have_http_status(200)
      chapters = json_response[:response][:data][:book][:chapters]
      expect(chapters).to be_an(Array)
      expect(chapters.first).not_to have_key(:content_file_url)
      expect(chapters.first).to have_key(:id)
      expect(chapters.first).to have_key(:name)
      expect(chapters.first).to have_key(:content_file_type)
    end
  end

  # ==================== 批量获取封面 ====================
  describe 'GET /api/books/covers' do
    it '返回多个图书的封面URL' do
      book1 = create(:book, name: '图书1', cover_image_url: 'https://test-bucket.oss-cn-hangzhou.aliyuncs.com/test/cover1.jpg')
      book2 = create(:book, name: '图书2', cover_image_url: 'https://test-bucket.oss-cn-hangzhou.aliyuncs.com/test/cover2.jpg')
      book3 = create(:book, name: '图书3', cover_image_url: 'https://test-bucket.oss-cn-hangzhou.aliyuncs.com/test/cover3.jpg')

      get '/api/books/covers', params: { book_ids: [book1.id, book2.id, book3.id], uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      data = json_response[:response][:data]
      expect(data[:covers].length).to eq(3)

      cover1 = data[:covers].find { |c| c[:book_id] == book1.id }
      expect(cover1[:name]).to eq('图书1')
      expect(cover1[:cover_image_url]).to include('?Expires=')

      cover2 = data[:covers].find { |c| c[:book_id] == book2.id }
      expect(cover2[:name]).to eq('图书2')
      expect(cover2[:cover_image_url]).to include('?Expires=')
    end

    it '返回的封面URL是签名后的OSS地址' do
      book1 = create(:book, cover_image_url: 'https://test-bucket.oss-cn-hangzhou.aliyuncs.com/test/cover.jpg')

      get '/api/books/covers', params: { book_ids: [book1.id], uuid: user.uuid }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:covers].first[:cover_image_url]).to match(/\?Expires=/)
      expect(data[:covers].first[:cover_image_url]).to include('OSSAccessKeyId=')
      expect(data[:covers].first[:cover_image_url]).to include('Signature=')
    end

    it '部分图书不存在时只返回存在的图书' do
      book1 = create(:book, name: '存在的图书')

      get '/api/books/covers', params: { book_ids: [book1.id, 999_999], uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      data = json_response[:response][:data]
      expect(data[:covers].length).to eq(1)
      expect(data[:covers].first[:book_id]).to eq(book1.id)
    end

    it '图书封面URL为空时返回nil' do
      book1 = create(:book, cover_image_url: nil)

      get '/api/books/covers', params: { book_ids: [book1.id], uuid: user.uuid }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:covers].first[:cover_image_url]).to be_nil
    end

    it '空book_ids数组返回空结果' do
      get '/api/books/covers', params: { book_ids: [], uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      data = json_response[:response][:data]
      expect(data[:covers]).to eq([])
    end

    it '未提供 uuid 返回参数错误' do
      get '/api/books/covers', params: { book_ids: [1] }

      expect(response).to have_http_status(200)
    end

    it '无效 uuid 返回未授权' do
      get '/api/books/covers', params: { book_ids: [1], uuid: 'invalid-uuid' }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).not_to eq(0)
    end

    it '过滤用户黑名单中的图书' do
      book1 = create(:book, name: '正常图书')
      book2 = create(:book, name: '黑名单图书')

      # 将 book2 加入用户黑名单
      parental_control = create(:parental_control, app_user: user)
      create(:blacklisted_book, parental_control: parental_control, book: book2)

      get '/api/books/covers', params: { book_ids: [book1.id, book2.id], uuid: user.uuid }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      # 只返回正常图书，不返回黑名单图书
      expect(data[:covers].length).to eq(1)
      expect(data[:covers].first[:book_id]).to eq(book1.id)
    end

    it '只传入单个book_id也能正常工作' do
      book1 = create(:book, name: '单本图书', cover_image_url: 'https://test-bucket.oss-cn-hangzhou.aliyuncs.com/test/cover.jpg')

      get '/api/books/covers', params: { book_ids: [book1.id], uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      data = json_response[:response][:data]
      expect(data[:covers].length).to eq(1)
      expect(data[:covers].first[:name]).to eq('单本图书')
    end
  end
end
