# myExperiment: app/models/membership_sweeper.rb
# 
# Copyright (c) 2007 University of Manchester and the University of Southampton.
# See license.txt for details.

class MembershipSweeper < ActionController::Caching::Sweeper

  include CachingHelper
  observe Membership

  def after_create(membership)
    expire_listing(membership.network_id, 'Network')
    expire_sidebar_assets(membership.user_id)
    expire_sidebar_user_monitor(membership.user_id)

    # expire network admins user monitor so membership request shows up
    network = get_network(membership.network_id)
    expire_sidebar_user_monitor(network.user_id)
  end

  def after_update(membership)
    expire_listing(membership.network_id, 'Network')
    expire_sidebar_assets(membership.user_id)
    expire_sidebar_user_monitor(membership.user_id)

    network = get_network(membership.network_id)
    expire_sidebar_user_monitor(network.user_id)
  end

  def after_destroy(membership)
    expire_listing(membership.network_id, 'Network')
    expire_sidebar_assets(membership.user_id)
    expire_sidebar_user_monitor(membership.user_id)

    network = get_network(membership.network_id)
    expire_sidebar_user_monitor(network.user_id)
  end

  private

  def get_network(network_id)
    Network.find(:first, :conditions => ["id = ?", network_id])
  end
end
