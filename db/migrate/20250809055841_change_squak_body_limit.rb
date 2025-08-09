class ChangeSquakBodyLimit < ActiveRecord::Migration[8.0]
  def up
    change_column :squaks, :body, :text
  end

  def down
    change_column :squaks, :body, :string, limit: 255
  end

end
