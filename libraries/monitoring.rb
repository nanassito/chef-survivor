class Chef
  class Recipe

    # Send an email alert if a directory is missing or out of sync
    def alert_on_out_of_sync(username, root, directories, monitoring_config)
      out_of_date = find_out_of_sync(root, directories, monitoring_config)
      email_on_failure = check_optional_input(monitoring_config,
                                              ['email_on_failure'],
                                              true)
      if !out_of_date.empty? and email_on_failure  # BUG
        send_email_alert(username, out_of_date, monitoring_config)
      end
    end

    def send_email_alert(username, directories, monitoring_config)
      require 'mail'

      smtp_options = check_input(monitoring_config, ['smtp'])
      smtp_options = smtp_options.inject({}){|m,(k,v)| m[k.to_sym] = v; m}
      Mail.defaults do
        delivery_method :smtp, smtp_options
      end

      host = node['fqdn']
      user = data_bag_item('users', username)
      assert(user, "Could not find databag `users.#{user}`.")
      assert(user['email'], "User `#{user}` needs an email address.")
      directories = directories.join("\n - ")
      Mail.deliver do
        # to user['email']  # FIXME: Redirect to the correct user once I solved the spam issue
        to 'dorian@jaminais.fr'
        from 'survivor'
        subject "Out of date backups for #{username} on #{host}."
        body "#{username.capitalize},\n"\
             "There is something wrong with the backups. Some canaries are "\
             "too old on #{host}. Here is the list of impacted directories:\n"\
             " - #{directories}\n"
             "\n"
             "Survivor monitor"
      end
    end

    # Find missing or out of sync directories
    def find_out_of_sync(root, directories, monitoring_config)
      max_day_old = check_optional_input(monitoring_config, ['max_day_old'], 5)
      canary = check_optional_input(monitoring_config,
                                    ['canary_name'],
                                    '.survivor.canary')
      out_of_date = directories.select do |directory|
        # Select old canaries
        path = "#{root}/#{directory}/#{canary}"
        begin
          canary_time = File.read(path).strip
        rescue Errno::ENOENT
          canary_time = '2000-01-01T00:00:00-07:00'  # Just something too old
        end
        age_day =(DateTime.now() - DateTime.strptime(canary_time)).to_i
        age_day > max_day_old
      end
      return out_of_date
    end

  end
end
