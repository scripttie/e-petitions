class UpdatePetitionDebateStates < ActiveRecord::Migration
  def up
    execute <<-SQL
      UPDATE petitions SET debate_state = 'awaiting'
      WHERE debate_threshold_reached_at IS NOT NULL
      AND scheduled_debate_date IS NULL
    SQL

    execute <<-SQL
      UPDATE petitions SET debate_state = 'scheduled'
      WHERE scheduled_debate_date >= CURRENT_DATE
    SQL

    execute <<-SQL
      UPDATE petitions SET debate_state = 'debated'
      WHERE scheduled_debate_date < CURRENT_DATE
    SQL

    execute <<-SQL
      UPDATE petitions SET debate_state = 'debated'
      WHERE debate_outcome_at IS NOT NULL
      AND id IN (SELECT petition_id FROM debate_outcomes WHERE debated = 't')
    SQL

    execute <<-SQL
      UPDATE petitions SET debate_state = 'not_debated'
      WHERE debate_outcome_at IS NOT NULL
      AND id IN (SELECT petition_id FROM debate_outcomes WHERE debated = 'f')
    SQL

    execute <<-SQL
      UPDATE petitions SET debate_state = 'pending'
      WHERE debate_state = 'closed'
    SQL
  end

  def down
    execute <<-SQL
      UPDATE petitions SET debate_state = 'pending'
      WHERE debate_threshold_reached_at IS NOT NULL
      AND scheduled_debate_date IS NULL
    SQL

    execute <<-SQL
      UPDATE petitions SET debate_state = 'awaiting'
      WHERE scheduled_debate_date >= CURRENT_DATE
    SQL

    execute <<-SQL
      UPDATE petitions SET debate_state = 'debated'
      WHERE scheduled_debate_date < CURRENT_DATE
    SQL

    execute <<-SQL
      UPDATE petitions SET debate_state = 'debated'
      WHERE debate_outcome_at IS NOT NULL
      AND id IN (SELECT petition_id FROM debate_outcomes WHERE debated = 't')
    SQL

    execute <<-SQL
      UPDATE petitions SET debate_state = 'none'
      WHERE debate_outcome_at IS NOT NULL
      AND id IN (SELECT petition_id FROM debate_outcomes WHERE debated = 'f')
    SQL

    execute <<-SQL
      UPDATE petitions SET debate_state = 'closed'
      WHERE state = 'closed'
      AND debate_threshold_reached_at IS NULL
      AND scheduled_debate_date IS NULL
      AND debate_outcome_at IS NULL
    SQL
  end
end
