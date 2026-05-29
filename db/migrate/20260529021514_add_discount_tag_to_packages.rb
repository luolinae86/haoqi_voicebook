class AddDiscountTagToPackages < ActiveRecord::Migration[8.0]
  def up
    add_column :packages, :discount_tag, :string unless column_exists?(:packages, :discount_tag)
  end

  def down
    remove_column :packages, :discount_tag if column_exists?(:packages, :discount_tag)
  end
end
