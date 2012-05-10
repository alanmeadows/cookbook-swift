#
# Cookbook Name:: swift
# Recipe:: ring-repo
#
# Copyright 2012, Rackspace Hosting
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# This recipe creates a git ring repository on the management node
# for purposes of ring synchronization
#

if platform?(%w{fedora})
  # fedora, maybe other rhel-ish dists
  git_packages = %w{git git-daemon}
  git_dir = "/var/lib/git"
else
  # debian, ubuntu, other debian-ish
  git_packages = %w{git git-daemon-sysvinit}
  git_dir = "/var/cache/git"
end

git_packages.each do |pkg|
  package pkg do
    action :upgrade
  end
end

execute "create empty git repo" do
  cwd "/tmp"
  umask 022
  command "mkdir $$; cd $$; git init; echo \"backups\" \> .gitignore; git add .gitignore; git commit -m 'initial commit' --author='chef <chef@openstack>'; git push file:///#{git_dir}/rings master"
  action :nothing
end

directory "git-directory" do
  path "#{git_dir}/rings"
  owner "swift"
  group "swift"
  mode "0755"
  recursive true
  action :create
end

execute "initialize git repo" do
  cwd "#{git_dir}/rings"
  umask 022
  user "swift"
  command "git init --bare && touch git-daemon-export-ok"
  creates "#{git_dir}/rings/config"
  action :run
  notifies :run, resources(:execute => "create empty git repo"), :immediately
end

# runs of of xinetd in redhat.  Perhaps it should run out of xinetd in
# debian/ubuntu too...

if platform?(%w{ubuntu})
  service "git-daemon" do
    action [ :enable, :start ]
  end

  cookbook_file "/etc/default/git-daemon" do
    owner "root"
    group "root"
    mode "644"
    source "git-daemon.default"
    action :create
    notifies :restart, resources(:service => "git-daemon"), :immediately
  end
end

directory "/etc/swift/ring-workspace" do
  owner "swift"
  group "swift"
  mode "0755"
  action :create
end

execute "checkout-rings" do
  cwd "/etc/swift/ring-workspace"
  command "git clone file:///var/cache/git/rings"
  user "swift"
  creates "/etc/swift/ring-workspace/rings"
end

# FIXME: node attribute - partition power
[ "account", "container", "object" ].each do |ring_type|
  execute "add #{ring_type}.builder" do
    cwd "/etc/swift/ring-workspace/rings"
    command "git add #{ring_type}.builder && git commit -m 'initial ring builders' --author='chef <chef@openstack>'"
    user "swift"
    action :nothing
  end

  execute "create #{ring_type} builder" do
    cwd "/etc/swift/ring-workspace/rings"
    command "swift-ring-builder #{ring_type}.builder create 18 3 1"
    user "swift"
    creates "/etc/swift/ring-workspace/rings/#{ring_type}.builder"
    notifies :run, "execute[add #{ring_type}.builder]", :immediate
  end
end

bash "rebuild-rings" do
  action :nothing
  cwd "/etc/swift/ring-workspace/rings"
  user "swift"
  code <<-EOF
    set -e
    set -x

    # Should this be done?
    git reset --hard
    git clean -df

    ../generate-rings.sh

    git add *builder *gz
    git commit -m "Autobuild of rings on $(date +%Y%m%d) by Chef" --author="chef <chef@openstack>"

    # should dsh a ring pull at this point
    git push
  EOF

  only_if { node["swift"]["auto_rebuild_rings"] }
end

swift_ring_script "/etc/swift/ring-workspace/generate-rings.sh" do
  owner "swift"
  group "swift"
  mode "0700"
  ring_path "/etc/swift/ring-workspace/rings"
  action :ensure_exists
  notifies :run, "bash[rebuild-rings]", :immediate
end

