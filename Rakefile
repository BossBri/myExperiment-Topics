# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require(File.join(File.dirname(__FILE__), 'config', 'boot'))

require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

require 'tasks/rails'

desc 'Rebuild Solr index'
task "myexp:refresh:solr" do
  require File.dirname(__FILE__) + '/config/environment'
  Workflow.rebuild_solr_index
  Blob.rebuild_solr_index
  User.rebuild_solr_index
  Network.rebuild_solr_index
  Pack.rebuild_solr_index
end

desc 'Refresh contribution caches'
task "myexp:refresh:contributions" do
  require File.dirname(__FILE__) + '/config/environment'

  all_viewings = Viewing.find(:all, :conditions => "accessed_from_site = 1").group_by do |v| v.contribution_id end
  all_downloads = Download.find(:all, :conditions => "accessed_from_site = 1").group_by do |v| v.contribution_id end

  Contribution.find(:all).each do |c|
    c.contributable.update_contribution_rank
    c.contributable.update_contribution_rating
    c.contributable.update_contribution_cache

    ActiveRecord::Base.record_timestamps = false

    c.reload
    c.update_attribute(:created_at, c.contributable.created_at)
    c.update_attribute(:updated_at, c.contributable.updated_at)

    c.update_attribute(:site_viewings_count,  all_viewings[c.id]  ? all_viewings[c.id].length  : 0)
    c.update_attribute(:site_downloads_count, all_downloads[c.id] ? all_downloads[c.id].length : 0)

    ActiveRecord::Base.record_timestamps = true
  end
end

desc 'Create a myExperiment data backup'
task "myexp:backup:create" do
  require File.dirname(__FILE__) + '/config/environment'
  Maintenance::Backup.create
end

desc 'Restore from a myExperiment data backup'
task "myexp:backup:restore" do
  require File.dirname(__FILE__) + '/config/environment'
  Maintenance::Backup.restore
end

