# frozen_string_literal: true

module Api
  module Grades
    class Mount < Grape::API
      mount Api::Grades::GradeApi
    end
  end
end
