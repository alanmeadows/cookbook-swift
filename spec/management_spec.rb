require_relative 'spec_helper'

describe 'swift::management-server' do

  #-------------------
  # UBUNTU
  #-------------------

  describe "ubuntu" do

    before do
      swift_stubs
      @chef_run = ::ChefSpec::ChefRunner.new ::UBUNTU_OPTS
      @node = @chef_run.node
      @node.set['lsb']['code'] = 'precise'
      @node.set['swift']['authmode'] = 'swauth'

      @chef_run.converge "swift::management-server"
    end

    it "installs swift swauth package" do
      expect(@chef_run).to install_package "swauth"
    end

    describe "/etc/swift/dispersion.conf" do

      before do
        @file = @chef_run.template "/etc/swift/dispersion.conf"
      end

      it "has proper owner" do
        expect(@file).to be_owned_by "swift", "swift"
      end

      it "has proper modes" do
        expect(sprintf("%o", @file.mode)).to eq "600"
      end

      it "template contents" do
        pending "TODO: implement"
      end

    end


    describe "/usr/local/bin/swift_statsd_publish.py" do

      before do
        @file = @chef_run.template "/usr/local/bin/swift_statsd_publish.py"
      end

      it "has proper owner" do
        expect(@file).to be_owned_by "root", "root"
      end

      it "has proper modes" do
        expect(sprintf("%o", @file.mode)).to eq "755"
      end

      it "template contents" do
        pending "TODO: implement"
      end

    end

  end

end
