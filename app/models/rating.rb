# myExperiment: app/models/rating.rb
#
# Copyright (c) 2007 University of Manchester and the University of Southampton.
# See license.txt for details.

class Rating < ActiveRecord::Base
  belongs_to :rateable, :polymorphic => true
  
  after_save    :update_contribution_rating
  after_destroy :update_contribution_rating
      
  # NOTE: Comments belong to a user
  belongs_to :user
  
  # Helper class method to lookup all ratings assigned
  # to all rateable types for a given user.
  def self.find_ratings_by_user(user)
    find(:all,
      :conditions => ["user_id = ?", user.id],
      :order => "created_at DESC"
    )
  end

  private

  def update_contribution_rating
    if rateable.contribution
      rateable.update_contribution_rating
    end
  end
end

