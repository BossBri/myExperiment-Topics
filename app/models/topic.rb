# myExperiment: app/models/topic.rb
#

class Topic < ActiveRecord::Base
  
  belongs_to :run, :class_name => "TopicRun", :foreign_key => "run_id"
  
  has_many :topic_tag_map,
           :class_name => "TopicTagMap",
		   :foreign_key => :topic_id,
		   :dependent => :destroy
		   
  has_many :topic_workflow_map,
           :class_name => "TopicWorkflowMap",
		   :foreign_key => :topic_id,
		   :dependent => :destroy		   

  has_many :topic_tag_feedback,
           :class_name => "TopicTagFeedback",
           :foreign_key => :topic_id,
           :dependent => :destroy
		   
  has_many :topic_feedback,
           :class_name => "TopicFeedback",
           :foreign_key => :topic_id,
           :dependent => :destroy
		   
  def name
    self.attributes["name"]
  end
		   
end