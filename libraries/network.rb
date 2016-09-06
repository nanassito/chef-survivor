class Chef
  class Recipe

    # Find the ip address of a host
    def get_ip(ip_version, hostname)
      if ip_version == 4
        ip_family = 'inet'
      elsif ip_version == 6
        ip_family = 'inet6'
      else
        throw 'Ip version has to be either 4 or 6 (prefered).'
      end

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
        spec['family'] == ip_family and spec['scope'] == 'Global'
      }.keys.pop
      assert(address, "Couldn't find ipv#{ip_version} address for `#{hostname}`")
      return address
    end

  end
end
