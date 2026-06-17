class CreateCircleReadStates < ActiveRecord::Migration[8.0]
  def change
    create_table :circle_read_states do |t|
      t.references :user, null: false, foreign_key: true
      t.references :circle, null: false, foreign_key: true
      t.datetime :last_read_at, null: false

      t.timestamps
    end

    add_index :circle_read_states, [:user_id, :circle_id], unique: true
  end
end
