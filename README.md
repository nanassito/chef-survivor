survivor Cookbook
=================

This configures a multi-host backup infrastructure.

The architecture is to have sources, typically laptops, have a cron job to rsync their data to a close by relay server. Then a remote server will use rsync-snapshot to backup the relay host.

Requirements
------------
This cookbook assumes that the relay host is visible by all the other machines. It also assumes that you have ipv6 connectivity (hello, this is 2016), also it shouldn't be too hard to tweak to use legacy ipv4.
Finally this cookbook assumes you are using the chef-user cookbook to manage your users and chef-openssh to manage your authorized keys.

e.g.
#### packages
- `openssh` - survivor needs openssh run rsync and rsync-snapshot.
- `users` - survivor needs users to make sure the defined users are available on all machines.

Attributes
----------
TODO: List your cookbook attributes here.

e.g.
#### survivor::default
<table>
  <tr>
    <th>Key</th>
    <th>Type</th>
    <th>Description</th>
    <th>Default</th>
  </tr>
  <tr>
    <td><tt>['survivor']['bacon']</tt></td>
    <td>Boolean</td>
    <td>whether to include bacon</td>
    <td><tt>true</tt></td>
  </tr>
</table>

Usage
-----
#### survivor::default
TODO: Write usage instructions for each cookbook.

e.g.
Just include `survivor` in your node's `run_list`:

```json
{
  "name":"my_node",
  "run_list": [
    "recipe[survivor]"
  ]
}
```

Contributing
------------
The goal of this cookbook is only to run my backup architecture. I want to make it as simple and reliable as possible for my user case. That said I think it could be valuable to others so feel free to remix to your use case. If you think we can improve to make things better for everyone else, please submit a merge request.

License and Authors
-------------------
Authors: Dorian Jaminais
