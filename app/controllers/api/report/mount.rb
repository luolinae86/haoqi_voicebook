# frozen_string_literal: true

module Api
  module Report
    class Mount < Grape::API
      mount Api::Report::ReportApi
    end
  end
end
