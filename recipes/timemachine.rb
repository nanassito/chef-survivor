#
# Cookbook Name:: survivor
# Recipe:: timemachine
#
# Configure rsnapshot and monitor the canary files


require 'pathname'


def assert(object, message)
  # Fuck ruby, leave the parenthesis or it does crap.
  empty = ([Hash, Array, String].include?(object.class) and object.empty?)
  if empty or !object
    throw message
  end
end


def check_input(object, path)
  path.each do |key|
    object = object[key]
    assert(object, "Required parameter `#{path.join('.')}` (#{object})")
  end
  return object
end


def get_ipv4(hostname)
  host = search(
    :node,
    "name:#{hostname}",
    :filter_result => {
      'default_iface' => ['network', 'default_inet6_interface'],
      'interfaces' => ['network' , 'interfaces'],
    },
  ).pop
  assert(host, "Could not find host `#{hostname}`.")
  addresses = host['interfaces'][host['default_iface']]['addresses']
  address = addresses.select { |addr, spec|
    spec['family'] == 'inet' and spec['scope'] == 'Global'
  }.keys.pop
  assert(address, "Couldn't find ipv4 address for `#{hostname}`")
  return address
end


def get_or_create_rsa(keypath)
  if File.exist?(keypath)
    privkey = File.read("#{keypath}").strip()
    pubkey = File.read("#{keypath}.pub").strip()
  else
    chef_gem 'sshkey'
    require 'sshkey'
    sshkey = SSHKey.generate(type: 'RSA', comment: "timemachine key")
    privkey = sshkey.private_key
    pubkey = sshkey.ssh_public_key
  end
  return privkey, pubkey
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
  relay_ip = get_ipv4(check_input(backup, ['relay', 'host']))
  relay_dir = check_input(backup, ['relay', 'directory'])
  max_day_old = check_input(backup, ['monitoring', 'max_day_old'])
  smtp_options = check_input(backup, ['monitoring', 'smtp'])
  source_dirs = check_input(backup, ['source', 'directories']).map do |d|
    Pathname.new(d).basename.to_s
  end


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


  # Install and configure rsnapshot
  package 'rsnapshot'
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
  privkey, pubkey = get_or_create_rsa(keypath)
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

  out_of_date = source_dirs.select do |directory|
    # Select old canaries
    path = "/home/#{username}/#{root}/days.0/data/#{directory}/.survivor.canary"
    begin
      canary_time = File.read(path).strip
    rescue Errno::ENOENT
      canary_time = '2000-01-01T00:00:00-07:00'  # Just something too old
    end
    age_day =(DateTime.now() - DateTime.strptime(canary_time)).to_i
    age_day > max_day_old
  end

  next if out_of_date.empty?

  chef_gem 'mail' do
    version '2.6.3'
  end

  # Send an email alert
  user = data_bag_item('users', username)
  assert(user, "Could not find databag `users.#{user}`.")
  assert(user['email'], "User `#{user}` needs an email address.")
  directories = out_of_date.join('\n - ')
  ruby_block 'send email alert' do
    block do
      host = node.fqdn
      smtp_options = smtp_options.inject({}){|m,(k,v)| m[k.to_sym] = v; m}
      require 'mail'
      Mail.defaults do
        delivery_method :smtp, smtp_options
      end
      Mail.deliver do
        to user['email']
        from 'survivor'
        subject 'Out of date backups'
        body "There is something wrong with the backups. Some canaries are "\
             "too old on #{host}. Here is the list of impacted directories:\n"\
             "- #{directories}\n"
             "\n"
             "Survivor - Timemachine"
      end
    end
    action :run
  end

end
