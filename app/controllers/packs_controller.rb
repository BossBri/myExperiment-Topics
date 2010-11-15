# myExperiment: app/controllers/packs_controller.rb
#
# Copyright (c) 2007 University of Manchester and the University of Southampton.
# See license.txt for details.

class PacksController < ApplicationController
  include ApplicationHelper
  
  before_filter :login_required, :except => [:index, :show, :search, :items, :download, :statistics]
  
  before_filter :find_pack_auth, :except => [:index, :new, :create, :search]
  
  before_filter :set_sharing_mode_variables, :only => [:show, :new, :create, :edit, :update]
  
  # declare sweepers and which actions should invoke them
  cache_sweeper :pack_sweeper, :only => [ :create, :update, :destroy ]
  cache_sweeper :pack_entry_sweeper, :only => [ :create_item, :quick_add, :update_item, :destroy_item ]
  cache_sweeper :permission_sweeper, :only => [ :create, :update, :destroy ]
  cache_sweeper :bookmark_sweeper, :only => [ :destroy, :favourite, :favourite_delete ]
  cache_sweeper :tag_sweeper, :only => [ :create, :update, :tag, :destroy ]
  cache_sweeper :download_viewing_sweeper, :only => [ :show, :download ]
  cache_sweeper :comment_sweeper, :only => [ :comment, :comment_delete ]

  def search
    redirect_to(search_path + "?type=packs&query=" + params[:query])
  end

  # GET /packs
  def index
    @contributions = Contribution.contributions_list(Pack, params, current_user)
    respond_to do |format|
      format.html # index.rhtml
    end
  end
  
  # GET /packs/1
  def show
    if allow_statistics_logging(@pack)
      @viewing = Viewing.create(:contribution => @pack.contribution, :user => (logged_in? ? current_user : nil), :user_agent => request.env['HTTP_USER_AGENT'], :accessed_from_site => accessed_from_website?())
    end
    
    respond_to do |format|
      format.html {
        
        @lod_nir  = pack_url(@pack)
        @lod_html = formatted_pack_url(:id => @pack.id, :format => 'html')
        @lod_rdf  = formatted_pack_url(:id => @pack.id, :format => 'rdf')
        @lod_xml  = formatted_pack_url(:id => @pack.id, :format => 'xml')
        
        # show.rhtml
      }

      if Conf.rdfgen_enable
        format.rdf {
          render :inline => `#{Conf.rdfgen_tool} packs #{@pack.id}`
        }
      end
    end
  end
  
  # GET /packs/1;download
  def download
    # this is done every time the donwload is requested;
    # however all versions of the archive are replacing each other,
    # so ultimately there's just one copy of a zip archive per pack
    # (this also makes sure that changes to the pack are reflected in the
    # zip, because it is generated on the fly every time) 
    
    # this hash contains all the paths to the images to be used as bullet icons in the pack item listing
    image_hash = {} 
    image_hash["workflow"] = "./public/images/" + method_to_icon_filename("workflow")
    image_hash["file"] = "./public/images/" + method_to_icon_filename("blob")
    image_hash["pack"] = "./public/images/" + method_to_icon_filename("pack")
    image_hash["link"] = "./public/images/" + method_to_icon_filename("remote")
    image_hash["denied"] = "./public/images/" + method_to_icon_filename("denied")
    
    @pack.create_zip(current_user, image_hash)
    
    if allow_statistics_logging(@pack)
      @download = Download.create(:contribution => @pack.contribution, :user => (logged_in? ? current_user : nil), :user_agent => request.env['HTTP_USER_AGENT'], :accessed_from_site => accessed_from_website?())
    end
    
    send_file @pack.archive_file_path, :disposition => 'attachment'
  end
  
  # GET /packs/new
  def new
    @pack = Pack.new
  end
  
  # GET /packs/1;edit
  def edit
  end
  
  # POST /packs
  def create
    
    params[:pack][:contributor_type], params[:pack][:contributor_id] = "User", current_user.id
    
    @pack = Pack.new(params[:pack])
    
    respond_to do |format|
      if @pack.save
        if params[:pack][:tag_list]
          @pack.tags_user_id = current_user
          @pack.tag_list = convert_tags_to_gem_format params[:pack][:tag_list]
          @pack.update_tags
        end
        
        # update policy
        policy_err_msg = update_policy(@pack, params)
        
        if policy_err_msg.blank?
          flash[:notice] = 'Pack was successfully created.'
          format.html { redirect_to pack_url(@pack) }
        else
          flash[:notice] = "Pack was successfully created. However some problems occurred, please see these below.</br></br><span style='color: red;'>" + policy_err_msg + "</span>"
          format.html { redirect_to :controller => 'packs', :id => @pack, :action => "edit" }
        end
      else
        format.html { render :action => "new" }
      end
    end
  end
  
  # PUT /packs/1
  def update
    
    # remove protected columns
    if params[:pack]
      [:contributor_id, :contributor_type, :created_at, :updated_at].each do |column_name|
        params[:pack].delete(column_name)
      end
    end
    
    respond_to do |format|
      if @pack.update_attributes(params[:pack])
        @pack.refresh_tags(convert_tags_to_gem_format(params[:pack][:tag_list]), current_user) if params[:pack][:tag_list]
        policy_err_msg = update_policy(@pack, params)
        
        if policy_err_msg.blank?
          flash[:notice] = 'Pack was successfully updated.'
          format.html { redirect_to pack_url(@pack) }
        else
          flash[:error] = policy_err_msg
          format.html { redirect_to :controller => 'packs', :id => @pack, :action => "edit" }
        end
      else
        format.html { render :action => "edit" }
      end
    end
  end
  
  # DELETE /packs/1
  def destroy
    success = @pack.destroy

    respond_to do |format|
      if success
        flash[:notice] = "Pack has been deleted."
        format.html { redirect_to packs_url }
      else
        flash[:error] = "Failed to delete Pack. Please contact your administrator."
        format.html { redirect_to pack_url(@pack) }
      end
    end
  end
  
  # POST /packs/1;favourite
  def favourite
    @pack.bookmarks << Bookmark.create(:user => current_user, :bookmarkable => @pack) unless @pack.bookmarked_by_user?(current_user)
    
    respond_to do |format|
      flash[:notice] = "You have successfully added this item to your favourites."
      format.html { redirect_to pack_url(@pack) }
    end
  end
  
  # DELETE /packs/1;favourite_delete
  def favourite_delete
    @pack.bookmarks.each do |b|
      if b.user_id == current_user.id
        b.destroy
      end
    end
    
    respond_to do |format|
      flash[:notice] = "You have successfully removed this item from your favourites."
      redirect_url = params[:return_to] ? params[:return_to] : pack_url(@pack)
      format.html { redirect_to redirect_url }
    end
  end
  
  # POST /packs/1;tag
  def tag
    @pack.tags_user_id = current_user # acts_as_taggable_redux
    @pack.tag_list = "#{@pack.tag_list}, #{convert_tags_to_gem_format params[:tag_list]}" if params[:tag_list]
    @pack.update_tags # hack to get around acts_as_versioned
    
    respond_to do |format|
      format.html { 
        render :update do |page|
          unique_tag_count = @pack.tags.uniq.length
          page.replace_html "mini_nav_tag_link", "(#{unique_tag_count})"
          page.replace_html "tags_box_header_tag_count_span", "(#{unique_tag_count})"
          page.replace_html "tags_inner_box", :partial => "tags/tags_box_inner", :locals => { :taggable => @pack, :owner_id => @pack.contributor_id } 
        end
      }
    end
  end
  
  def new_item
    # If a uri has been provided lets resolve it now
    uri = preprocess_uri(params[:uri])
    if uri
      errors, @type, @item_entry = @pack.resolve_link(uri, request.host, request.port.to_s, current_user)
      unless errors.empty?
        @error_message = errors.full_messages.to_sentence(:connector => '')
      end
    end
    
    # Will render packs/new_item.rhtml
  end
  
  def create_item
    respond_to do |format|
      uri = preprocess_uri(params[:uri])
      if !uri.blank?
        errors, @type, @item_entry = @pack.resolve_link(uri, request.host, request.port.to_s, current_user)
       
        # By this point, we either have errors, or have an entry that needs saving.
        if errors.empty?
          @item_entry.comment = params[:comment]
          if @item_entry.save
            if !params[:return_to].blank?
              flash[:notice] = "Item succesfully added to pack."
              format.html { redirect_to params[:return_to] }
            else
              flash[:notice] = "Item succesfully added to pack. You can now edit it and add more metadata here (or click 'Return to Pack')"
              format.html { redirect_to url_for({ :controller => "packs", :id => @pack.id, :action => "edit_item", :entry_type => @type, :entry_id => @item_entry.id }) }
            end
          else
            flash.now[:error] = "Failed to add item to pack. See any errors below."
            format.html { render :action => "new_item" }
          end
        else
          @error_message = errors.full_messages.to_sentence(:connector => '')
          flash.now[:error] = 'Failed to add item to pack. See errors below.'
          format.html { render :action => "new_item" }
        end
      else
        flash.now[:error] = "Failed to add item to pack."
        format.html { render :action => "new_item" }
      end
    end
  end
  
  def edit_item
    if params[:entry_type].blank? or params[:entry_id].blank?
      error("Invalid item entry specified for editing", "")
    else
      @type = params[:entry_type].downcase
      @item_entry = find_entry(@pack.id, params[:entry_type], params[:entry_id])
    end
    
    # Will render packs/new_item.rhtml
  end
  
  def update_item
    # Attempt to retrieve the entry that needs updating
    if !params[:entry_type].blank? and !params[:entry_id].blank?
      @type = params[:entry_type].downcase
      entry = find_entry(@pack.id, params[:entry_type], params[:entry_id])
    end
    
    respond_to do |format|
      if entry
        case params[:entry_type].downcase
          when 'contributable'
            # Nothing to update specifically here
          when 'remote'
            entry.title = params[:title]
            
            # check that a protocol is specified in the URI; prepend HTTP:// otherwise
            # \A[a-z]+:// - Matches '<protocol>://<address>'
            uri = preprocess_uri(params[:uri])
            entry.uri = uri
            
            alternate_uri = preprocess_uri(params[:alternate_uri])
            entry.alternate_uri = alternate_uri
        end
        
        entry.comment = params[:comment]
        
        if entry.save
          flash[:notice] = 'Successfully updated item entry.'
          format.html { redirect_to pack_url(@pack) }
        else
          @item_entry = entry
          flash.now[:error] = 'Failed to update item entry.'
          format.html { render :action => "edit_item" }
        end
      else
        flash[:error] = "Failed to update item entry."
        format.html { redirect_to pack_url(@pack) }
      end
    end
  end
  
  def destroy_item
    # Note: at this point, we are assuming that authorisation for deleting of items has been given by a before_filter method
    
    # Attempt to retrieve the entry that needs deleting
    if !params[:entry_type].blank? and !params[:entry_id].blank?
      entry = find_entry(@pack.id, params[:entry_type], params[:entry_id])
    end
    
    respond_to do |format|
      if entry
        entry.destroy
        flash[:notice] = "Successfully deleted item entry."
        format.html { redirect_to pack_url(@pack) }
      else
        flash[:error] = "Failed to delete item entry."
        format.html { redirect_to pack_url(@pack) }
      end
    end
  end
  
  def quick_add
    respond_to do |format|
      uri = preprocess_uri(params[:uri])
      if uri.blank?
        flash.now[:error] = 'Failed to add item. See error(s) below.'
        @error_message = "Please enter a link"
        format.html { render :action => "show" }
      else
        errors, type, entry = @pack.resolve_link(uri, request.host, request.port.to_s, current_user)
        
        # By this point, we either have errors, or have an entry that needs saving.
        if errors.empty?
          unless entry.save
            copy_errors(entry.errors, errors)
          end
        end
        
        if errors.empty?
          flash[:notice] = 'Item succesfully added to pack.'
          format.html { redirect_to pack_url(@pack) }
        else
          flash.now[:error] = 'Failed to add item. See error(s) below.'
          @error_message = errors.full_messages.to_sentence(:connector => '')
          format.html { render :action => "show" }
        end
      end
    end
  end
  
  def resolve_link
    respond_to do |format|
      uri = preprocess_uri(params[:uri])
      if uri.blank?
        @error_message = "Please enter a link"
      else
        errors, @type, @item_entry = @pack.resolve_link(uri, request.host, request.port.to_s, current_user)
        unless errors.empty?
          @error_message = errors.full_messages.to_sentence(:connector => '')
        end
      end
      
      format.html { render :partial => "after_resolve", :locals => { :error_message => @error_message, :type => @type, :item_entry => @item_entry } }
    end
  end
  
  def items
    respond_to do |format|
      format.rss { render :action => 'items.rxml', :layout => false }
    end
  end
  
  protected
  
  # Check that a protocol is specified in the URI; prepend HTTP:// otherwise
  def preprocess_uri(uri)
    expr = /\A[a-z]+:\/\//    # aka \A[a-z]+:// - Matches '<protocol>://<address>'  
    if !uri.blank? && !uri.match(expr)
      return uri = "http://" + uri;
    else
      return uri
    end
  end
  
  def find_pack_auth
    begin
      pack = Pack.find(params[:id])
      
      if Authorization.is_authorized?(action_name, nil, pack, current_user)
        @pack = pack
        
        @authorised_to_edit = logged_in? && Authorization.is_authorized?("edit", nil, @pack, current_user)
        @authorised_to_download = Authorization.is_authorized?("download", nil, @pack, current_user)
        
        @pack_entry_url = url_for :only_path => false,
                            :host => base_host,
                            :id => @pack.id
                            
        @base_host = base_host
      else
        error("You are not authorised to perform this action", "is not authorized")
        return false
      end
    rescue ActiveRecord::RecordNotFound
      error("Pack not found", "is invalid")
      return false
    end
  end
  
  def set_sharing_mode_variables
    case action_name
      when "new"
        @sharing_mode  = 0
        @updating_mode = 6
      when "create", "update"
        @sharing_mode  = params[:sharing][:class_id].to_i if params[:sharing]
        @updating_mode = params[:updating][:class_id].to_i if params[:updating]
      when "show", "edit"
        @sharing_mode  = @pack.contribution.policy.share_mode
        @updating_mode = @pack.contribution.policy.update_mode
    end
  end
  
  private
  
  def error(notice, message, attr=:id)
    flash[:error] = notice
    (err = Pack.new.errors).add(attr, message)
    
    respond_to do |format|
      format.html { redirect_to packs_url }
    end
  end
  
  # This finds the specified entry within the specified pack (otherwise returns nil).
  def find_entry(pack_id, entry_type, entry_id)
    case entry_type.downcase
      when 'contributable' 
        return PackContributableEntry.find(:first, :conditions => ["id = ? AND pack_id = ?", entry_id, pack_id])
      when 'remote'
        return PackRemoteEntry.find(:first, :conditions => ["id = ? AND pack_id = ?", entry_id, pack_id])
      else
        return nil
    end
  end
  
  # Utility method to copy error messages from one ActiveRecord::Errors object to another.
  def copy_errors(source_errs, final_errs)
    source_errs.each_full do |msg|
      final_errs.add_to_base(msg)
    end
  end
end
