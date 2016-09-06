#
# Cookbook Name:: survivor
# Recipe:: relay
#
# Monitor the canaries to alert when a backup is out of date.

chef_gem 'mail' do
  version '2.6.3'
end
include_recipe 'users::sysadmins'
include_recipe 'openssh'


# Enable rrsync
rrsync_path = '/usr/local/bin/rrsync'
execute 'install rrsync' do
  command "gunzip /usr/share/doc/rsync/scripts/rrsync.gz -c > #{rrsync_path}"
  not_if do ::File.exists?(rrsync_path) end
end
file rrsync_path do
  mode '0755'
end


node['survivor'].each do |backup|

  relay_host = check_input(backup, ['relay', 'host'])
  next unless relay_host == node.name

  # Verify inputs
  username = check_input(backup, ['username'])
  root = check_input(backup, ['relay', 'directory'])
  monitoring_config = check_input(backup, ['monitoring'])
  source_dirs = check_input(backup, ['source', 'directories']).collect do |dir|
    dir.split("/")[-1]  # Take only the directory name
  end

  alert_method = method(:alert_on_out_of_sync)
  ruby_block "send email alert for survivor #{backup}" do
    block do
      alert_method.call(
        username,
        "/home/#{username}/#{root}",
        source_dirs,
        monitoring_config,
      )
    end
    action :run
  end

end
