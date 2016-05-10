#
# Cookbook Name:: survivor
# Recipe:: timemachine
#
# Snapshot the data from the relay server


# Install rsnapshot
package "rsnapshot"



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

  # Generate rsnapshot configuration file

  # Set up cron jobs

end
