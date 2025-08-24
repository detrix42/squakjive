class CreateUserInvites < ActiveRecord::Migration[8.0]
  def change
    create_table :user_invites do |t|
      t.references :circle, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
    add_index :user_invites, [:circle_id, :user_id], unique: true
  end
end
