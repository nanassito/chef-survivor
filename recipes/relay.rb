#
# Cookbook Name:: survivor
# Recipe:: relay
#
# Monitor the canaries to alert when a backup is out of date.


def assert(object, message)
  if not object or object.empty?
    Chef::Application.fatal!(message)
  end
end


def check_input(object, path)
  path.each do |key|
    object = object[key]
    assert(object, "Required parameter `#{path.join('.')}`")
  end
  return object
end


node['survivor'].each do |backup|

  email_on_failure = check_input(backup, ['monitoring', 'email_on_failure'])
  next unless email_on_failure

  # Verify inputs
  username = check_input(backup, ['username'])
  root = check_input(backup, ['relay', 'directory'])
  max_day_old = check_input(backup, ['monitoring', 'max_day_old'])
  canary = check_input(backup, ['monitoring', 'canary_name'])
  directories = check_input(backup, ['source', 'directories']).collect do |dir|
    dir.split("/")[1]  # Take only the directory name
  end

  out_of_date = directories.select do |directory|
    # Find old canaries
    path = "/home/#{username}/#{root}#{directory}/#{canary}"
    canary_time = File.read(path).strip
    age_day =(DateTime.now() - DateTime.strptime(canary_time)).to_i
    age_day > max_day_old
  end

  next if out_of_date.empty?

  user = data_bag_item('users', username)
  assert(user, "Could not find databag `users.#{user}`.")
  assert(user['email'], "User `#{user}` needs an email address.")
  Pony.mail(
    :to => user['email'],
    :from => "chef-client@#{node.fqdn}",
    :subject => "Out of date backups on #{node.name}",
    :body => "The following directories have out of date canaries:\n"\
             " - #{out_of_date.join('\n - ')}\n"\
             "\n"\
             "fix it, fix it, fix it!"
  )

end







# Need to find who is going to write where and create the directory ?


# 1- Find all backup directories
# 2- Read all canaries
# 3- Find outdated canaries
# 4- Send summary email if there is any problems

search(
  :node,
  "rsynced_laptops_target_host:raspi",
  :filter_result => {
    'username' => ['rsynced', 'laptops'],
  },
).collect do |laptop|

  "/home/#{username}/#{target}#{directories}"
end

canary_time = File.read("path/to/file").strip
age_day =(DateTime.now() - DateTime.strptime(canary_time)).to_i
if age > 60 * 60 * 24
  Pony.mail(
    :to => "infra@jaminais.fr",
    :from => "chef-client@#{node.fqdn}",
    :subject => "Some backups are outdated",
    :body => body
  )
end
