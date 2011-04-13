class CreateTopicFeedback < ActiveRecord::Migration
  def self.up
    create_table :topic_feedback do |t|
	  t.column :user_id, :integer
	  t.column :topic_id, :integer
	  t.column :score, :integer 
	  t.column :submit_dt, :date
	end
  end
  
  def self.down
    drop_table :topic_feedback
  end
end
