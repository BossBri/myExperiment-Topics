# myExperiment: app/models/attribution.rb
#

require 'acts_as_site_entity'
require 'acts_as_contributable'
require 'acts_as_creditable'
require 'acts_as_attributor'
require 'acts_as_attributable'
require 'explicit_versioning'
require 'acts_as_reviewable'
require 'acts_as_runnable'

require 'scufl/model'
require 'scufl/parser'

class Topic < ActiveRecord::Base

  attr_accessor :name

  has_many :topic_tag_feedback,
           :class_name => "TopicTagFeedback",
           :foreign_key => :topic_id,
           :dependent => :destroy
		   
  has_many :topic_feedback,
           :class_name => "TopicFeedback",
           :foreign_key => :topic_id,
           :dependent => :destroy
end