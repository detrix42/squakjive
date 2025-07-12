class CreateSquaks < ActiveRecord::Migration[8.0]
  def change
    create_table :squaks do |t|
      t.references :user, null: false, foreign_key: true
      t.string :body

      t.timestamps
    end
  end
end
