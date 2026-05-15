# frozen_string_literal: true

module Api
  module Compilations
    class Mount < Grape::API
      mount Api::Compilations::CompilationApi
    end
  end
end
