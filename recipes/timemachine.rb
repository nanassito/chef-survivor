#
# Cookbook Name:: survivor
# Recipe:: timemachine
#
# Configure rsnapshot and monitor the canary files


require 'pathname'


# Common set up for all backups
directory '/etc/rsnapshot/' do
  owner 'root'
  group 'root'
  mode '0755'
end
directory '/var/run/rsnapshot/' do
  owner 'root'
  group 'sysadmin'
  mode '0775'
end
package 'rsnapshot'
chef_gem 'mail' do
  version '2.6.3'
end


# Set up each backup
node['survivor'].each_index do |idx|
  backup = node['survivor'][idx]
  timemachine_host = check_input(backup, ['timemachine', 'host'])
  next unless timemachine_host == node.name


  # Verify inputs
  username = check_input(backup, ['username'])
  root = check_input(backup, ['timemachine', 'directory'])
  retention_policy = check_input(backup, ['timemachine', 'retention_policy'])
  relay_ip = get_ip(4, check_input(backup, ['relay', 'host']))
  relay_dir = check_input(backup, ['relay', 'directory'])
  monitoring_config = check_input(backup, ['monitoring'])
  source_dirs = check_input(backup, ['source', 'directories']).map do |d|
    Pathname.new(d).basename.to_s
  end


  # Configure rsnapshot
  config_path = "/etc/rsnapshot/#{username}.conf"
  template config_path do
    source 'rsnapshot.conf.erb'
    owner 'root'
    group 'root'
    mode '0644'
    variables({
      :snapshot_root => root,
      :dependencies => {
        :cp => '/bin/cp',
        :rm => '/bin/rm',
        :rsync => '/usr/bin/rsync',
        :ssh => '/usr/bin/ssh',
        :logger => '/usr/bin/logger',
        :du => '/usr/bin/du',
        :rsnapshot_diff => '/usr/bin/rsnapshot-diff',
      },
      :retention_policy => retention_policy,
      :username => username,
      :source_ip => relay_ip,
      :source_dir => relay_dir,
    })
  end


  # Generate a RSA key if needed
  ssh_dir = "/home/#{username}/.ssh"
  keypath = "#{ssh_dir}/id_rsa_timemachine"
  privkey, pubkey = get_or_create_rsa(keypath, "timemachine key")
  directory ssh_dir do
    owner username
    group 'root'
    mode 00700
  end
  file keypath do
    content privkey
    mode '0600'
    owner username
  end
  file "#{keypath}.pub" do
    content pubkey
    mode '0644'
    owner username
  end


  # Push RSA public key to the user data bag
  user = data_bag_item('users', username)
  assert(user, "Could not find databag `users.#{user}`.")
  cli = [
      "command=\"/usr/local/bin/rrsync ~/\"",
      "no-agent-forwarding",
      "no-port-forwarding",
      "no-pty",
      "no-user-rc",
      "no-X11-forwarding",
  ].join(',')
  entry = "#{cli} #{pubkey}"
  user['ssh_keys'] = [] unless user['ssh_keys']
  user['ssh_keys'].push(entry) unless user['ssh_keys'].include? entry
  user.save


  # Configure cron jobs
  cron "install timemachine rsync cron for survivor #{idx}" do
    minute  "10-59/5"  # Do not sync on the first 10 minutes of each hour.
    hour    "*"
    day     "*"
    month   "*"
    user    username
    command "rsnapshot -c #{config_path} sync"
  end
  cron "install timemachine monthly cron for survivor #{idx}" do
    minute  "1"
    hour    "1"
    day     "1"
    month   "*"
    user    username
    command "rsnapshot -c #{config_path} months"
  end
  cron "install timemachine daily cron for survivor #{idx}" do
    minute  "3"
    hour    "1"
    day     "*"
    month   "*"
    user    username
    command "rsnapshot -c #{config_path} days"
  end
  cron "install timemachine hourly cron for survivor #{idx}" do
    minute  "5"
    hour    "*"
    day     "*"
    month   "*"
    user    username
    command "rsnapshot -c #{config_path} hours"
  end

  alert_method = method(:alert_on_out_of_sync)
  ruby_block "send email alert for survivor #{idx}" do
    block do
      alert_method.call(
        username,
        "/home/#{username}/#{root}/days.0/data",
        source_dirs,
        monitoring_config,
      )
    end
    action :run
  end

end
