# myExperiment: app/controllers/pictures_controller.rb
#
# Copyright (c) 2007 University of Manchester and the University of Southampton.
# See license.txt for details.

class PicturesController < ApplicationController
  before_filter :login_required, :except => [:index, :show]
  
  before_filter :find_pictures, :only => [:index]
  before_filter :find_picture_auth, :only => [:select, :edit, :update, :destroy]
  
  # GET /users/1/pictures/1/select
  # GET /pictures/1/select
  def select
    if @picture.select!
      # create and save picture selection record
      PictureSelection.create(:user => current_user, :picture => @picture)
      
      respond_to do |format|
        flash[:notice] = 'Picture was successfully selected as profile picture.'
        format.html { redirect_to pictures_url(@picture.owner) }
      end
    else
      error("Picture already selected", "already selected")
    end
  end
  
  # GET /users/1/pictures
  # GET /pictures
  def index
    respond_to do |format|
      format.html # index.rhtml
    end
  end

  # GET /users/1/pictures/1
  # GET /pictures/1
  def show
    size = params[:size] || "200x200"
    size = size[0..-($1.length.to_i + 2)] if size =~ /[0-9]+x[0-9]+\.([a-z0-9]+)/ # trim file extension
    
    id = params[:id].to_i

    send_cached_data("public/pictures/show/#{size}/#{id}.jpg",
        :type => 'image/jpeg', :disposition => 'inline') {

      find_picture

      # resize and encode the picture
      @picture.resize!(:size => size)
      @picture.to_jpg!

      @picture.data
    }

  end
  
  # GET /users/1/pictures/new
  # GET /pictures/new
  def new
    @picture = Picture.new
  end

  # GET /users/1/pictures/1;edit
  # GET /pictures/1;edit
  def edit
    
  end

  # POST /users/1/pictures
  # POST /pictures
  def create
    @picture = Picture.create(:data => params[:picture][:data], :user_id => current_user.id)

    respond_to do |format|
      if @picture.save
        flash[:notice] = 'Picture was successfully uploaded.'
        
        #format.html { redirect_to pictures_url(@picture.user_id) }
        # updated to take account of possibly various locations from where this method can be called,
        # so multiple redirect options are possible -> now return link is passed as a parameter
        format.html { redirect_to params[:redirect_to] }
      else
        format.html { render :action => "new" }
      end
    end
  end

  # PUT /users/1/pictures/1
  # PUT /pictures/1
  def update
    respond_to do |format|
      if @picture.update_attributes(params[:picture])
        flash[:notice] = 'Picture was successfully updated.'
        format.html { redirect_to pictures_url(@picture.user_id) }
      else
        format.html { render :action => "edit" }
      end
    end
  end

  # DELETE /users/1/pictures/1
  # DELETE /pictures/1
  def destroy
    user_id = @picture.user_id
    
    @picture.destroy

    respond_to do |format|
      format.html { redirect_to user_pictures_url(user_id) }
    end
  end
  
protected

  def find_pictures
    if params[:user_id]
      @pictures = Picture.find(:all, :conditions => ["user_id = ?", params[:user_id]])
    elsif logged_in?
      redirect_to pictures_url(current_user)
    else
      error("Please supply a User ID", "not supplied", :user_id)
    end
  end
  
  def find_picture
    if params[:id]
      if picture = Picture.find(:first, :conditions => ["id = ?", params[:id]])
        @picture = picture
      else
        error("Picture not found (id not found)", "is invalid (not found)")
      end
    else
      error("Please supply an ID", "not supplied")
    end
  end

  def find_picture_auth
    if params[:user_id]
      begin
        @picture = Picture.find(params[:id], :conditions => ["user_id = ?", params[:user_id]])
      rescue ActiveRecord::RecordNotFound
        error("Picture not found (id not authorized)", "is invalid (not owner)")
      end
    else
      error("Please supply a User ID", "not supplied", :user_id)
    end
  end

private
  
  def error(notice, message, attr=:id)
    flash[:error] = notice
    (err = Picture.new.errors).add(attr, message)
    
    respond_to do |format|
      format.html { redirect_to logged_in? ? pictures_url(current_user) : '' }
    end
  end

  # file system cache

  def send_cached_data(file_name, *opts)

    if !File.exists?(file_name)
      FileUtils.mkdir_p(File.dirname(file_name))
      File.open(file_name, "wb+") { |f| f.write(yield) }
    end

    send_file(file_name, *opts)
  end
end

