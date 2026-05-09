# frozen_string_literal: true

desc "Add schema annotations to all models"
namespace :db do
  namespace :migrate do
    task :annotate => :environment do
      models = Dir.glob(Rails.root.join("app/models/*.rb"))
                 .reject { |f| f.end_with?("application_record.rb") }
                 .map { |f| File.basename(f, ".rb") }

      models.each do |model_name|
        model = model_name.classify.constantize rescue next
        next unless model < ActiveRecord::Base rescue next

        table = model.table_name
        columns = model.connection.columns(table)
        indexes = model.connection.indexes(table)

        # Build schema comment
        schema = []
        schema << "# == Schema Information"
        schema << "#"
        schema << "# Table name: #{table}"
        schema << "#"
        schema << "#  #{columns.map { |col| column_info(col) }.join("\n#  ")}"

        # Add index info
        if indexes.any?
          schema << "#"
          indexes.each do |idx|
            schema << "#  Index: #{idx.name} on #{idx.columns.join(', ')}#{' (unique)' if idx.unique}"
          end
        end

        schema << "#"

        # Read existing file content
        file_path = Rails.root.join("app/models/#{model_name.underscore}.rb")
        content = File.read(file_path)

        # Remove existing schema annotation (may appear multiple times)
        content = content.gsub(/# == Schema Information\n(?:#.*\n)*?(?:#?\n)+(?=\s*(?:#|class|module))/, "")

        # Add new annotation at the top
        annotated = schema.join("\n") + "\n#\n" + content

        File.write(file_path, annotated)
        puts "Annotated #{model_name}"
      end

      puts "Done!"
    end

    private

    def column_info(col)
      type_str = col.limit ? "#{col.type}(#{col.limit})" : col.type.to_s
      attrs = []
      attrs << "not null" if col.null == false
      attrs << "default(#{col.default})" if col.default.present?
      attrs << "primary key" if col.name == "id"
      attr_str = attrs.join(", ")

      " #{col.name.ljust(20)} #{type_str.ljust(18)} #{attr_str}"
    end
  end
end
