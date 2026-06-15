class AddMcpToUserProfile < ActiveRecord::Migration[8.0]
  def change
    add_column :user_profiles, :is_mcp, :boolean, default: false
  end
end
