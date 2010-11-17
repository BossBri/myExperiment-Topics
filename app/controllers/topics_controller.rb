# myExperiment: app/controllers/topics_controller.rb
#
# Copyright (c) 2007 University of Manchester and the University of Southampton.
# See license.txt for details.

class TopicsController < ApplicationController
  before_filter :login_required, :except => [:index, :show]
  

  # declare sweepers and which actions should invoke them
  cache_sweeper :workflow_sweeper, :only => [ :create, :create_version, :launch, :update, :update_version, :destroy_version, :destroy ]
  cache_sweeper :download_viewing_sweeper, :only => [ :show, :download, :named_download, :launch ]
  cache_sweeper :permission_sweeper, :only => [ :create, :update, :destroy ]
  cache_sweeper :bookmark_sweeper, :only => [ :destroy, :favourite, :favourite_delete ]
  cache_sweeper :tag_sweeper, :only => [ :create, :update, :tag, :destroy ]
  cache_sweeper :comment_sweeper, :only => [ :comment, :comment_delete ]
  cache_sweeper :rating_sweeper, :only => [ :rate ]
  
  # These are provided by the Taverna gem
  require 'scufl/model'
  require 'scufl/parser'
  require 'scufl/dot'
 
  # GET /workflows
  def index
    respond_to do |format|
      format.html do
        @contributions = Contribution.contributions_list(Workflow, params, current_user)
        # index.rhtml
      end
      format.rss do
        #@workflows = Workflow.find(:all, :order => "updated_at DESC") # list all (if required)
        render :action => 'index.rxml', :layout => false
      end
    end
  end
    
protected

  def find_workflows_rss
    # Only carry out if request is for RSS
    if params[:format] and params[:format].downcase == 'rss'
      @rss_workflows = Authorization.authorised_index(Workflow, :all, :limit => 30, :order => 'updated_at DESC', :authorised_user => current_user)
    end
  end
  
  def find_workflow_auth
    begin
      # Use eager loading only for 'show' action
      if action_name == 'show'
        workflow = Workflow.find(params[:id], :include => [ { :contribution => :policy }, :citations, :tags, :ratings, :versions, :reviews, :comments ])
      else
        workflow = Workflow.find(params[:id])
      end
      
      if Authorization.is_authorized?(action_name, nil, workflow, current_user)
        @latest_version_number = workflow.current_version
        @workflow = workflow
        if params[:version]
          if (viewing = @workflow.find_version(params[:version]))
            @viewing_version_number = params[:version].to_i
            @viewing_version = viewing
          else
            error("Workflow version not found (possibly has been deleted)", "not found (is invalid)", :version)
          end
        else
          @viewing_version_number = @latest_version_number
          @viewing_version = @workflow.find_version(@latest_version_number)
        end
        
        @authorised_to_edit = logged_in? && Authorization.is_authorized?('edit', nil, @workflow, current_user)
        if @authorised_to_edit
          # can save a call to .is_authorized? if "edit" was already found to be allowed - due to cascading permissions
          @authorised_to_download = true
        else
          @authorised_to_download = Authorization.is_authorized?('download', nil, @workflow, current_user)
        end
        
        # remove scufl from workflow if the user is not authorized for download
        @viewing_version.content_blob.data = nil unless @authorised_to_download
        @workflow.content_blob.data = nil unless @authorised_to_download
          
        @workflow_entry_url = url_for :only_path => false,
                                :host => base_host,
                                :id => @workflow.id
        
        @download_url = url_for :action => 'download',
                                :id => @workflow.id, 
                                :version => @viewing_version_number.to_s
        
        @named_download_url = url_for @workflow.named_download_url + "?version=#{@viewing_version_number.to_s}" 
                                      
        @launch_url = "/workflows/#{@workflow.id}/launch.whip?version=#{@viewing_version_number.to_s}"

        logger.debug("@latest_version_number = #{@latest_version_number}")
        logger.debug("@viewing_version_number = #{@viewing_version_number}")
        logger.debug("@workflow.image != nil = #{@workflow.image != nil}")
      else
        error("Workflow not found (id not authorized)", "is invalid (not authorized)")
        return false
      end
    rescue ActiveRecord::RecordNotFound
      error("Workflow not found", "is invalid")
      return false
    end
  end
  
  def initiliase_empty_objects_for_new_pages
    if ["new", "create"].include?(action_name)
      @workflow = Workflow.new
    end
    
    # HACK: required for the FCKEditor description and revision comments boxes, 
    # (the former is used in both new and new_version actions).
    @new_workflow = Workflow.new
    
    if ["new_version", "create_version"].include?(action_name)
      # Set the fields to the metadata from the previous version,
      # to aid user in setting the metadata.
      @new_workflow.body = @workflow.body
      params[:workflow] = { } unless params[:workflow]
      params[:workflow][:title] = @workflow.title
      # Determine which main metadata option to pre select based on whether metadata inference is supported for the workflow type.
      @workflow.can_infer_metadata_for_this_type? ? params[:metadata_choice] = "infer" : params[:metadata_choice] = "custom"
    end
    
    @new_workflow.body = params[:new_workflow][:body] if params[:new_workflow] && params[:new_workflow][:body]
    
    # Add a 'rev_comments' field to just this instance so that the FCKEditor box can pick it up.
    @new_workflow.extend Module.new { attr_accessor :rev_comments }
      
    if params[:new_workflow] && params[:new_workflow][:rev_comments]
      @new_workflow.rev_comments = params[:new_workflow][:rev_comments]
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
        @sharing_mode  = @workflow.contribution.policy.share_mode
        @updating_mode = @workflow.contribution.policy.update_mode
    end
  end
  
  def check_file_size
    case action_name
      when "create"           then view_to_render_on_fail = "new"
      when "create_version"   then view_to_render_on_fail = "new_version"
    end
    
    # Check that a file has been selected 
    if params[:workflow][:file].size == 0
      respond_to do |format|
        flash.now[:error] = "Please select a valid workflow file to upload. If you have selected a file, it might be empty."
        format.html { render :action => view_to_render_on_fail }
      end
      return false
    # Check that the size of the workflow file doesn't exceed the max size
    elsif params[:workflow][:file].size > Conf.max_upload_size
      respond_to do |format|
        flash.now[:error] = "The workflow file/script uploaded is too big. The maximum upload size for workflows is #{number_to_human_size(Conf.max_upload_size)}."
        format.html { render :action => view_to_render_on_fail }
      end
      return false
    end
  end
  
private

  def error(notice, message, attr=:id)
    flash[:error] = notice
    (err = Workflow.new.errors).add(attr, message)
    
    respond_to do |format|
      format.html { redirect_to workflows_url }
    end
  end
  
  # Method used in the create and create_version methods.
  def infer_metadata(workflow_to_set, file)
    # Rewind the file, just in case
    file.rewind
    
    # Try and get a processor that can be used to process this type of workflow
    processor_class = WorkflowTypesHandler.processor_class_for_file(file)
    
    # Rewind the file, just in case
    file.rewind
    
    # Status check variable
    worked = true
    
    if processor_class.nil?
      worked = false
      logger.debug("A workflow processor for the file uploaded could not be found!")
    else
      # Check that the processor can do inferring of metadata
      if processor_class.can_infer_metadata?
        begin
          processor_instance = processor_class.new(file.read)
          
          # Rewind the file, just in case
          file.rewind
          
          workflow_to_set.title = processor_instance.get_title
          workflow_to_set.body = processor_instance.get_description
          
          workflow_to_set.content_type = ContentType.find_by_title(processor_class.display_name)
          
          # Set the internal unique name for this particular workflow (or workflow_version).
          workflow_to_set.set_unique_name
          
          workflow_to_set.image = processor_instance.get_preview_image if processor_class.can_generate_preview_image?
          workflow_to_set.svg   = processor_instance.get_preview_svg   if processor_class.can_generate_preview_svg?
        rescue Exception => ex
          worked = false
          err_msg = "ERROR: some processing failed in workflow processor '#{processor_class.to_s}'.\nEXCEPTION: #{ex}"
          logger.error err_msg
        end
      else
        # We cannot infer metadata
        worked = false
        logger.debug("Workflow processor found but it cannot infer metadata!")
      end
    end
    
    return worked
  end
  
  # Method used in the create and create_version methods.
  def set_custom_metadata(workflow_to_set, file)
    worked = true
    
    workflow_to_set.title = params[:workflow][:title]
    workflow_to_set.body = params[:new_workflow][:body]
    
    # Only set content_type if not already set in the workflow object
    if workflow_to_set.content_type.blank?
      # Workflow content type is either one supported by a workflow processor, or a previously set type in the db, or a custom one.
    
      wf_type = params[:workflow][:type]
    
      if wf_type.downcase == 'other'

        # Reuse an existing ContentType record if it exists already but the UI didn't have it.
     
        ct = ContentType.find_by_title(params[:workflow][:type_other])

        if ct.nil?
          ct = ContentType.create(:user_id => current_user.id,
            :mime_type => file.content_type, :title => params[:workflow][:type_other])
        end

        workflow_to_set.content_type = ct
      else
        workflow_to_set.content_type = ContentType.find_by_title(wf_type)
      end
    end
    
    # Check that the file uploaded is valid for the content type chosen (if supported by a workflow processor).
    # This is to ensure that the correct content type is being assigned to the workflow file uploaded.
    return false unless workflow_file_matches_content_type_if_supported?(file, workflow_to_set)
    
    # Preview image
    # TODO: kept getting permission denied errors from the file_column and rmagick code, so disable for windows, for now.
    unless RUBY_PLATFORM =~ /mswin32/
      workflow_to_set.image = params[:workflow][:preview]
    end
    
    # Set the internal unique name for this particular workflow (or workflow_version).
    workflow_to_set.set_unique_name
    
    return worked
  end
  
  # This method checks to to see if the file specified is a valid one for the existing workflow specified,
  # but only if the existing workflow specified has a supporting processor.
  # If no supporting processor is found then validity cannot be determined so we assume the file is valid for the content type.
  #
  # Note: this will check whether the file extension is supported and, if the processor allows for it, 
  # checks if the file is "recognised" by the processor as a valid workflow of that type.
  def workflow_file_matches_content_type_if_supported?(file, existing_workflow)
    ok = true
    
    proc_class = existing_workflow.processor_class
      
    if proc_class
      # Check that the file extension of the file specified is supported by the processor.
      file_ext = file.original_filename.split(".").last.downcase
      ok = false unless proc_class.file_extensions_supported.include?(file_ext)
      
      # Now check that the file can be "recognised", if the processor allows for this.
      # We do this by checking that the processor class, obtained from the types handler, for the specified file matches 
      # the processor class obtained before, for the content type specified.
      if proc_class.can_determine_type_from_file?
        if proc_class != WorkflowTypesHandler.processor_class_for_file(file)
          ok = false
        end
      end
    end
    return ok
  end

end

