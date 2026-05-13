# frozen_string_literal: true

module Api
  module Chapters
    class Mount < Grape::API
      mount Api::Chapters::ChapterApi
    end
  end
end
