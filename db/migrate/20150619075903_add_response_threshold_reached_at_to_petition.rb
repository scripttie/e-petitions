class AddResponseThresholdReachedAtToPetition < ActiveRecord::Migration
  def change
    change_table :petitions do |t|
      t.datetime :response_threshold_reached_at
      t.index :response_threshold_reached_at
    end
  end
end
