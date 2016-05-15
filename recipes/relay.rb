#
# Cookbook Name:: survivor
# Recipe:: relay
#
# Monitor the canaries to alert when a backup is out of date.


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


node['survivor'].each do |backup|

  relay_host = check_input(backup, ['relay', 'host'])
  next unless relay_host == node.name

  include_recipe 'users::sysadmins'
  include_recipe 'openssh'

  email_on_failure = check_input(backup, ['monitoring', 'email_on_failure'])
  next unless email_on_failure

  # Verify inputs
  username = check_input(backup, ['username'])
  root = check_input(backup, ['relay', 'directory'])
  max_day_old = check_input(backup, ['monitoring', 'max_day_old'])
  canary = check_input(backup, ['monitoring', 'canary_name'])
  smtp_options = check_input(backup, ['monitoring', 'smtp'])
  directories = check_input(backup, ['source', 'directories']).collect do |dir|
    dir.split("/")[-1]  # Take only the directory name
  end

  out_of_date = directories.select do |directory|
    # Select old canaries
    path = "/home/#{username}/#{root}/#{directory}/#{canary}"
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
             "- #{directories}"
      end
    end
    action :run
  end

end
