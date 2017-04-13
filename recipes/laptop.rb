#
# Cookbook Name:: survivor
# Recipe:: laptop
#
# Set up a cron job to rsync the directories to the relay host.


# Install rsync
package "rsync"
package "util-linux"


# Will put pid files in there
directory '/var/run/survivor' do
  owner 'root'
  group 'root'
  mode 00777
end


node['survivor'].each_index do |idx|
  backup = node['survivor'][idx]
  source = check_input(backup, ['source', 'host'])
  next unless source == node.name

  # Verify inputs
  username = check_input(backup, ['username'])
  directories = check_input(backup, ['source', 'directories'])
  schedule = check_input(backup, ['source', 'schedule'])
  target_host = check_input(backup, ['relay', 'host'])
  target_dir = check_input(backup, ['relay', 'directory'])
  canary = check_input(backup, ['monitoring', 'canary_name'])

  # Create a semaphore file to make sure rsync only executes once at a time
  semaphore_file = "/var/run/survivor/survivor.laptop.#{idx}"
  file semaphore_file do
    action :create_if_missing
    mode 0555
    owner username
  end


  # Generate a RSA key if needed
  ssh_dir = "/home/#{username}/.ssh"
  keypath = "#{ssh_dir}/id_rsa_rsynced"
  privkey, pubkey = get_or_create_rsa(keypath, "rsynced key")
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


  # Set up cron job
  addr = get_ip(6, target_host)
  cron "install rsync cron for survivor #{idx}" do
    time    schedule['time']
    minute  schedule['minute']
    hour    schedule['hour']
    day     schedule['day']
    month   schedule['month']
    weekday schedule['weekday']
    user    username
    command [
      "flock -n #{semaphore_file}",  # semaphore
      '/usr/bin/nice -n 19',  # nice
      '/usr/bin/ionice -c2 -n7',  # ionice
      '/usr/bin/rsync',
      '-azH',  # all, compress, hard links
      "--include='#{canary}'",  # include the canary file
      '--exclude=".*"',  # ignore dot files
      '--delete',  # propagate deletions
      "-e 'ssh -i #{keypath}'",  # ssh options
      directories.join(' '),  # directories
      "[#{addr}]:#{target_dir}",
    ].join(' ')
  end


  # Set up canary file to identify breakage in the pipeline
  require 'date'
  directories.each do |directory|
    file "#{directory}/#{canary}" do
      content DateTime.now().to_s
      mode '0600'
      owner username
    end
  end

end
