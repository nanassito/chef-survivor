survivor Cookbook
=================

This configures a multi-host backup infrastructure.

The architecture consists of sources, relay and timemachine.
The sources are typically laptops and rsync their data to the relay which should be close most of the time. Then the timemachine server downloads from the relay and keep several versions using rsync-snapshot.


Requirements
------------
* This assumes all your boxes runs Linux, it may work on other environment but it was written nor tested for this.
* This assumes the relay server is visible from all other boxes

e.g.
#### packages
- `openssh` - survivor needs openssh run rsync and rsync-snapshot.
- `users` - survivor needs users to make sure the defined users are available on all machines.


Attributes
----------

The root of `survivor` is a list of survivor configurations. That way you can have multiple backup configuration. I find it easier to have a configuration per laptop to be backed up.

### survivor::root
<table>
  <tr>
    <th>Key</th>
    <th>Type</th>
    <th>Description</th>
    <th>Default</th>
  </tr>
  <tr>
    <td><tt>['survivor'][0]['username']</tt></td>
    <td>String</td>
    <td>username to use for this backup. It must be defined in the `users` databag as defined in the users cookbook (https://supermarket.chef.io/cookbooks/users).</td>
    <td>Required</td>
  </tr>
  <tr>
    <td><tt>['survivor'][0]['monitoring']</tt></td>
    <td>Object</td>
    <td>Object to configure the behavior of the monitoring.</td>
    <td>Required</td>
  </tr>
  <tr>
    <td><tt>['survivor'][0]['source']</tt></td>
    <td>Object</td>
    <td>Object to configure the behavior of the sources (laptops).</td>
    <td>Required</td>
  </tr>
  <tr>
    <td><tt>['survivor'][0]['relay']</tt></td>
    <td>Object</td>
    <td>Object to configure the behavior of the relay server.</td>
    <td>Required</td>
  </tr>
  <tr>
    <td><tt>['survivor'][0]['timemachine']</tt></td>
    <td>Object</td>
    <td>Object to configure the behavior of the timemachine server.</td>
    <td>Required</td>
  </tr>
</table>

### survivor::monitoring
<table>
  <tr>
    <th>Key</th>
    <th>Type</th>
    <th>Description</th>
    <th>Default</th>
  </tr>
  <tr>
    <td><tt>['survivor'][0]['monitoring']['email_on_failure']</tt></td>
    <td>String</td>
    <td>Whether to email in case of failures or not. Setting this to false effectively disable monitoring. The email used is the email of the user as defined in the `users` databag.</td>
    <td><tt>True</tt></td>
  </tr>
  <tr>
    <td><tt>['survivor'][0]['monitoring']['max_day_old']</tt></td>
    <td>Integer</td>
    <td>Maximum number of days the canary can be delayed before triggering an email alert.</td>
    <td><tt>5</tt></td>
  </tr>
  <tr>
    <td><tt>['survivor'][0]['monitoring']['canary_name']</tt></td>
    <td>String</td>
    <td>Name of the file to use as a canary to make sure the backup are working properly. This file will be created in every top level directories to backup.</td>
    <td><tt>.survivor.canary</tt></td>
  </tr>
  <tr>
    <td><tt>['survivor'][0]['monitoring']['smtp']</tt></td>
    <td>Object</td>
    <td>Smtp configuration to pass to the Mail library. See http://www.rubydoc.info/github/mikel/mail/Mail.defaults for more information.</td>
    <td><tt></tt></td>
  </tr>
</table>

### survivor::source
<table>
  <tr>
    <th>Key</th>
    <th>Type</th>
    <th>Description</th>
    <th>Default</th>
  </tr>
  <tr>
    <td><tt>['survivor'][0]['source']['host']</tt></td>
    <td>String</td>
    <td>Host name to use as a relay. We expect to be able to find this machine in chef to lookup a routable ip address.</td>
    <td>Required</td>
  </tr>
  <tr>
    <td><tt>['survivor'][0]['source']['directories']</tt></td>
    <td>List<String></td>
    <td>List of directories to backup. Only use absolute paths.</td>
    <td>Required</td>
  </tr>
  <tr>
    <td><tt>['survivor'][0]['source']['schedule']</tt></td>
    <td>Object</td>
    <td>Schedule to run rsync on the laptops. The recommended value is ever couple of minutes. THe more often you sync the better. Survivor will prevent multiple instance of the same rsync and will run everything as low priority to not impact the performance of the laptop. Running very frequent backups also makes sure you will loose less data and that each backup is faster. This object is passed to the cron chef resources. We will use the following fields if defined: `time, `minute, `hour, `day, `month, `weekday`. See https://docs.chef.io/resource_cron.html for their usage.</td>
    <td>Required</td>
  </tr>
</table>

### survivor::relay
<table>
  <tr>
    <th>Key</th>
    <th>Type</th>
    <th>Description</th>
    <th>Default</th>
  </tr>
  <tr>
    <td><tt>['survivor'][0]['relay']['host']</tt></td>
    <td>String</td>
    <td>Chef node that will serve as relay. The assumption is that the relay is accessible from both the laptops and the timemachine node. It also works better if the relay is close by like the laptop like on the same network.</td>
    <td>Required</td>
  </tr>
  <tr>
    <td><tt>['survivor'][0]['relay']['directory']</tt></td>
    <td>String</td>
    <td>Directory on the relay node where the data will be backed up.</td>
    <td>Required</td>
  </tr>
</table>

### survivor::timemachine
<table>
  <tr>
    <th>Key</th>
    <th>Type</th>
    <th>Description</th>
    <th>Default</th>
  </tr>
  <tr>
    <td><tt>['survivor'][0]['timemachine']['host']</tt></td>
    <td>String</td>
    <td>Chef node to use as a timemachine host. The timemachine host can be anywhere in the world. THe only assumption is that it can talk to the relay node.</td>
    <td>Required</td>
  </tr>
  <tr>
    <td><tt>['survivor'][0]['timemachine']['directory']</tt></td>
    <td>String</td>
    <td>Directory on the timemachine node where the data will be backed up to. Keep in mind we will keep multiple revision of your data (albeit with de-dup) so you need significant disk space there.</td>
    <td>Required</td>
  </tr>
  <tr>
    <td><tt>['survivor'][0]['timemachine']['retention_policy']</tt></td>
    <td>String</td>
    <td>Map with the possible following keys "hours", "days", "months". The value is the number of backups to keep. For instance the following configuration {"hours": 2, "days":3, "months": 4} means we will keep versions for the last 2 hours, the last 3 days and the last 4 months.</td>
    <td>Required</td>
  </tr>
</table>


Contributing
------------
Do whatever you want with it. If you think you have found a bug you can open a ticket, if you have a new cool feature or fix, feel free to submit a pull request.


License and Authors
-------------------
Authors: Dorian Jaminais
