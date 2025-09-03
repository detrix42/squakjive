class RemoveBodyFromSquaks < ActiveRecord::Migration[8.0]

    def up
      remove_column :squaks, :body, :text # or :string if that’s what your original migration used
    end

    def down
      add_column :squaks, :body, :text
    end
end
