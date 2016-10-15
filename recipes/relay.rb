#
# Cookbook Name:: survivor
# Recipe:: relay
#
# Set up the relay node to receive data from the laptops.

include_recipe 'users::sysadmins'
include_recipe 'openssh'
include_recipe 'survivor::monitoring'


# Enable rrsync
rrsync_path = '/usr/local/bin/rrsync'
execute 'install rrsync' do
  command "gunzip /usr/share/doc/rsync/scripts/rrsync.gz -c > #{rrsync_path}"
  not_if do ::File.exists?(rrsync_path) end
end
file rrsync_path do
  mode '0755'
end
