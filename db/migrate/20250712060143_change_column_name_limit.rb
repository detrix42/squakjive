class ChangeColumnNameLimit < ActiveRecord::Migration[8.0]
  def change
    change_column :squaks, :body, :text, limit: 512
  end
end
