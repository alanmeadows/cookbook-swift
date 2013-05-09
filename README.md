Description
====

Installs packages and configuration for OpenStack Swift

Requirements
====

Client:
 * CentOS >= 6.3
 * Ubuntu >= 12.04

Chef:
 * 0.10.8

Other variants of Ubuntu and Fedora may work, something crazy like
Solaris probably will not.  YMMV, objects in mirror, etc.

Attributes
====

 * node[:swift][:authmode] - "swauth" or "keystone" (default "swauth"). Right now, only swauth is supported.

 * node[:swift][:swift_hash] - swift_hash_path_suffix in /etc/swift/swift.conf

 * node[:swift][:audit_hour] - Hour to run swift_auditor on storage nodes (default 5)

 * node[:swift][:disk_enum_expr] - Eval-able expression that lists
   candidate disk nodes for disk probing.  The result shoule be a hash
   with keys being the device name (without the leading "/dev/") and a
   hash block of any extra info associated with the device.  For
   example: { "sdc" => { "model": "Hitachi 7K3000" }}.  Largely,
   though, if you are going to make a list of valid devices, you
   probably know all the valid devices, and don't need to pass any
   metadata about them, so { "sdc" => {}} is probably enough.  Example
   expression: Hash[('a'..'f').to_a.collect{|x| [ "sd{x}", {} ]}]


The following swift initial ring construction parameters can be customized,
however they are set to safe defaults even for production environments
allowing up to 50,000 spindles:

  * default[:swift][:ring][:part_power] 
  * default[:swift][:ring][:min_part_hours] 
  * default[:swift][:ring][:replicas]

 * node[:swift][:disk_test_filter] - an array of expressions that must
   all be true in order a block deviced to be considered for
   formatting and inclusion in the cluster.  Each rule gets evaluated
   with "candidate" set to the device name (without the leading
   "/dev/") and info set to the node hash value.  Default rules:

    * "candidate =~ /sd[^a]/ or candidate =~ /hd[^a]/ or candidate =~
      /vd[^a]/"

    * "File.exists?('/dev/ + candidate)"

    * "not system('/sbin/sfdisk -V /dev/' + candidate + '>/dev/null 2>&2')"

    * "info['removable'] = 0" ])

 * node[:swift][:expected_disks] - an array of device names that the
   operator expecs to be identified by the previous two values.  This
   acts as a second-check on discovered disks.  If this array doesn't
   match the found disks, then chef processing will be stopped.
   Example: ("b".."f").collect{|x| "sd#{x}"}.  Default: none.

There are other attributes that must be set depending on authmode.
For "swauth", the following attributes are used:

 * node[:swift][:authkey] - swauth "swauthkey" if using swauth

In addition, because swift is typically deployed as a cluster
there are some attributes used to find interfaces and ip addresses
on storage nodes:

 * node[:swift][:network][:proxy-bind-ip] - the IP address to bind to
   on the proxy servers, defaults to 0.0.0.0 for all addresses.
 * node[:swift][:network][:proxy-bind-port] - the port to bind to
   on the proxy servers, defaults to 8080
 * node[:swift][:network][:account-bind-ip] - the IP address to bind to
   on the account servers, defaults to 0.0.0.0 for all addresses.
 * node[:swift][:network][:account-bind-port] - the port to bind to
   on the account servers, defaults to 6002
 * node[:swift][:network][:container-bind-ip] - the IP address to bind to
   on the container servers, defaults to 0.0.0.0 for all addresses.
 * node[:swift][:network][:container-bind-port] - the port to bind to
   on the container servers, defaults to 6002
 * node[:swift][:network][:object-bind-ip] - the IP address to bind to
   on the object servers, defaults to 0.0.0.0 for all addresses.
 * node[:swift][:network][:object-bind-port] - the port to bind to
   on the container servers, defaults to 6002
 * node[:swift][:network][:object-cidr] - the CIDR network for your object
   servers in order to build the ring, defaults to 10.0.0.0/24

Deps
====

 * apt

Roles
====

 * swift-account-server - storage node for account data
 * swift-container-server - storage node for container data
 * swift-object-server - storage node for object server
 * swift-proxy-server - proxy for swift storge nodes
 * swift-management-server - basically serves two functions:
   * proxy node with account management enabled
   * ring repository and ring building workstation
   THERE CAN ONLY BE ONE HOST WITH THE MANAGMENET SERVER ROLE!
 * swift-all-in-one - role shortcut for all object classes and proxy
   on one machine.

In small environments, it is likely that all storage machines will
have all-in-one roles, with a load balancer ahead of it

In larger environments, where it is cost effective to split the proxy
and storage layer, storage nodes will carry
swift-{account,container,object}-server roles, and there will be
dedicated hosts with the swift-proxy-server role.

In really really huge environments, it's possible that the storage
node will be split into swift-{container,accout}-server nodes and
swift-object-server nodes.

Examples
====

Example environment:


    {
	"default_attributes": {
	    "swift": {
		"swift_hash": "107c0568ea84",
		"authmode": "swauth",
		"authkey": "test"
                "auto_rebuild_rings": false
                "git_builder_ip": "10.0.0.10"
                "swauth": {
                    "url": "http://10.0.0.10:8080/v1/"
                }

	    },
	},
	"cookbook_versions": {
	},
	"description": "",
	"default_attributes": {
	},
	"name": "swift",
	"chef_type": "environment",
	"json_class": "Chef::Environment"
    }

This sets up defaults for a swauth-based cluster with the storage
network on 10.0.0.0/24.

Example all-in-one storage node config (note there is only one node
with the swift-setup role)

    {
      "id":       "storage1",
      "name":     "storage1",
      "json_class": "Chef::Node",
      "run_list": [
          "role[swift-setup]",
          "role[swift-management-server]",
          "role[swift-account-server]",
          "role[swift-object-server]",
          "role[swift-container-server]",
          "role[swift-proxy-server]"
      ],
      "chef_environment": "development",
      "normal": {
        "swift": {
          "zone": "1"
        }
      }
    }

Example storage-server role:

    {
      "name": "swift-object-server",
      "json_class": "Chef::Role",
      "run_list": [
        "recipe[apt]",
        "recipe[swift::object-server]"
      ],
      "description": "A storage server role.",
      "chef_type": "role"
    }

Run list for proxy server:

    "run_list": [
        "role[swift-proxy-server]"
    ]

Run list for combined object, container, and account server:

    "run_list": [
        "role[swift-object-server]",
        "role[swift-container-server]",
        "role[swift-account-server]"
    ]

In addition, there *must* be a node with the the
swift-managment-server role to act as the ring repository.
a

License and Author
====

Author:: Ron Pedde (<ron.pedde@rackspace.com>)
Author:: Will Kelly (<will.kelly@rackspace.com>)

Copyright:: 2012, Rackspace US, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

