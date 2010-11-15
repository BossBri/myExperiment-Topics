# myExperiment: app/controllers/userhistory_controller.rb
#
# Copyright (c) 2007 University of Manchester and the University of Southampton.
# See license.txt for details.

class UserhistoryController < ApplicationController
  before_filter :login_required, :only => [:index]
  
  before_filter :find_user, :only => [:show]
  
  # GET /userhistory
  def index
    respond_to do |format|
      format.html # index.rhtml
    end
  end
  
  # GET /users/1/userhistory
  # GET /userhistory/1
  def show
    respond_to do |format|
      format.html # show.rhtml
    end
  end
  
protected

  def find_user
    if params[:user_id]
      begin
        @user = User.find(params[:user_id])
    
      rescue ActiveRecord::RecordNotFound
        error("User not found", "is invalid", :user_id)
        return false
      end
    else
      @user = User.find(params[:id])
    end
  end

private

  def error(notice, message, attr=:id)
    flash[:error] = notice
    (err = User.new.errors).add(attr, message)
    
    respond_to do |format|
      format.html { redirect_to users_url }
    end
  end
  
end
