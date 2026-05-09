class DropDeprecatedModels < ActiveRecord::Migration[8.0]
  TABLES = %w[
    audio_albums
    audio_episodes
    banners
    categories
    chapters
    collections
    collection_items
    grades
    hot_searches
    rankings
    ranking_items
    reading_levels
    reading_records
    recommendations
    recommendation_items
  ].freeze

  def up
    TABLES.each do |table|
      drop_table table if table_exists?(table)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
