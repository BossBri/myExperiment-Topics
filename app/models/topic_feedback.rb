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

class TopicFeedback < ActiveRecord::Base
  belongs_to :topic
  validates_presence_of :topic
  
  belongs_to :user
  validates_presence_of :user
end