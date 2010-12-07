class CreateTopicWorkflowMap < ActiveRecord::Migration
  def self.up
    create_table :topic_workflow_map do |t|
	  t.column :topic_id, :integer
	  t.column :workflow_id, :integer
	  t.column :probability, :float
	  t.column :display_flag, :boolean
	end
  end
  
  def self.down
    drop_table :topic_workflow_map
  end
end