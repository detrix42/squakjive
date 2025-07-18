class CreateCircleMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :circle_memberships do |t|
      t.references :circle, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
