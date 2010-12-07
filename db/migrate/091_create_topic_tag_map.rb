class CreateTopicTagMap < ActiveRecord::Migration
  def self.up
    create_table :topic_tag_map do |t|
	  t.column :topic_id, :integer
	  t.column :tag_id, :integer
	  t.column :probability, :float
	  t.column :display_flag, :boolean
	end
  end
  
  def self.down
    drop_table :topic_tag_map
  end
end