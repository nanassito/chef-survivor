default["survivor"] = []

# Here is an example object to put in the `survivor` list:
{
  # User owning this backup. It must be defined in the `users` databag.
  :username => "johndoe",

  # Survivor place a canary file in each directory to back up. These settings
  # are use to decide how to alert when a canary is too old.
  :monitoring => {
    # Email the backup user. The email address is from the `users` data bag.
    :email_on_failure => true,
    # Maximum number of days before an email is sent.
    :max_day_old => 5,
    # Name of the canary file
    :canary_name => ".survivor.canary",
    # smtp settings
    :smtp => {
      :server => "smtp.gmail.com",
      :port => 587,
      :user_name => 'email@address',
      :password => 'my_password',
      :authentication => 'plain',
      :enable_starttls_auto => true,
    },
  },

  # Settings for the origin of the backup, typically a laptop. It mush be a
  # chef-managed machine in the same enviromnent.
  :source => {
    # Chef name of the host
    :host => "chef_managed_laptop",
    # Directories to include in the backup. They must be readable by the user.
    :directories => [
      "/home/john/Documents",
      "/home/john/Pictures"
    ],
    # Cron schedule of the rsync job, you can use anything from
    # https://docs.chef.io/resource_cron.html
    :schedule => {
      :minute => "*/5",
      :hour => "*",
      :day => "*",
      :month => "*"
    }
  },

  # Relay server where the data will first be uploaded. This is typically a
  # server that is often close to the source. This must be a chef managed
  # machine, accessible by both the source and timemachine hosts.
  :relay => {
    # Chef name of the host
    :host => "chef_managed_home_server",
    # Directory where the data will be rsynced into. This is relative to the
    # users home directory.
    :directory => "data/"
  },

  # Timemachine server. This host will contain multiple version of the data.
  # It is typically an offsite server. It is the machine requiring the most
  # disk capacity. This must also be a chef managed machine.
  :timemachine => {
    # Chef name of the host
    :host => "chef_managed_remote_server",
    # Top level directory where to store the data
    :directory => "/data",
    # Versioning definition
    :versions => {
      :hourly_qty => 5,  # Keep 5 hours
      :daily_qty => 5,  # Keep 5 days
      :weekly_qty => 2,  # Keep 2 weeks
      :monthly_qty => 1,  # Keep 1 month
      :yearly_qty => 0,  # Keep 0 year
    },
  }
}
