class CreateTopicTagFeedback < ActiveRecord::Migration
  def self.up
    create_table :topic_tag_feedback do |t|
	  t.column :topic_id, :integer
	  t.column :tag_id, :integer
	  t.column :user_id, :integer
	  t.column :probability, :float
	  t.column :display_flag, :boolean
	  t.column :score, :integer 
	  t.column :submit_dt, :date
	end
  end
  
  def self.down
    drop_table :topic_tag_feedback
  end
end