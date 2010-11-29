class CreateTopics < ActiveRecord::Migration
  def self.up
    create_table :topics do |t|
	  t.column :name, :string
	  t.column :run_id, :integer
	end
  end
  
  def self.down
    drop_table :topics
  end
end