#
# Cookbook Name:: survivor
# Recipe:: monitoring
#
# Set up the necessary artifact to make sure monitoring works.

chef_gem 'mail' do
  version '2.6.3'
end


node['survivor'].each do |backup|

  relay_host = check_input(backup, ['relay', 'host'])
  timemachine_host = check_input(backup, ['timemachine', 'host'])

  # Read and verify common inputs
  username = check_input(backup, ['username'])
  monitoring_config = check_input(backup, ['monitoring'])
  source_dirs = check_input(backup, ['source', 'directories']).collect do |dir|
    dir.split("/")[-1]  # Take only the directory name
  end

  if relay_host == node.name
    root = check_input(backup, ['relay', 'directory'])
    abs_root = "/home/#{username}/#{root}"
  else timemachine_host == node.name
    root = check_input(backup, ['timemachine', 'directory'])
    abs_root = "/home/#{username}/#{root}/days.0/data"
  end

  alert_method = method(:alert_on_out_of_sync)
  ruby_block "send email alert for survivor #{backup}" do
    block do
      alert_method.call(
        username,
        abs_root,
        source_dirs,
        monitoring_config,
      )
    end
    action :run
  end

end
