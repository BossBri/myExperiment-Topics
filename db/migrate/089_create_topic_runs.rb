class CreateTopicRuns < ActiveRecord::Migration
  def self.up
    create_table :topic_runs do |t|
	  t.column :description, :string
	  t.column :runtime, :datetime
	end
  end
  
  def self.down
    drop_table :topic_runs
  end
end