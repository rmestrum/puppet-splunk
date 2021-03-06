require "#{File.join(File.dirname(__FILE__),'..','spec_helper.rb')}"

describe 'splunk' do

  let(:title) { 'splunk' }
  let(:node) { 'rspec.example42.com' }
  let(:facts) { { :ipaddress => '10.42.42.42' } }

  describe 'Test standard installation' do
    it { should contain_package('splunk').with_ensure('latest') }
    it { should contain_service('splunk').with_ensure('running') }
    it { should contain_service('splunk').with_enable('true') }
  end

  describe 'Test standard installation with monitoring and firewalling' do
    let(:params) { {:monitor => true , :firewall => true, :port => '42' } }

    it { should contain_package('splunk').with_ensure('latest') }
    it { should contain_service('splunk').with_ensure('running') }
    it { should contain_service('splunk').with_enable('true') }
    it 'should monitor the process' do
      content = catalogue.resource('monitor::process', 'splunk_process').send(:parameters)[:enable]
      content.should == true
    end
    it 'should place a firewall rule' do
      content = catalogue.resource('firewall', 'splunk_tcp_42').send(:parameters)[:enable]
      content.should == true
    end
  end

  describe 'Test splunk installation with 2 forward servers' do
    let(:params) { {:forward_server => [ "splunk1.example42.com:9997" , "splunk2.example42.com:9997"] } }
    it { should contain_exec('splunk_add_forward_server') }
    it { should contain_file('splunk_add_forward_server').with_content(/splunk add forward-server splunk1.example42.com:9997 --accept-license --answer-yes --auto-ports --no-prompt -auth admin:changeme/) }
    it { should contain_file('splunk_add_forward_server').with_content(/splunk add forward-server splunk2.example42.com:9997 --accept-license --answer-yes --auto-ports --no-prompt -auth admin:changeme/) }
  end

  describe 'Test splunk installation with deployment server' do
    let(:params) { {:deployment_server => "splunk1.example42.com:8098" } }
    it { should contain_file('splunk_deployment_server').with_ensure('present') }
    it { should contain_file('splunk_deployment_server').with_content(/\[deployment-client\]\n\n\[target-broker:deploymentServer\]\ntargetUri = splunk1.example42.com:8098/) }
  end

  describe 'Test splunk installation without deployment server' do
    it { should contain_file('splunk_deployment_server').with_ensure('absent') }
  end

  describe 'Test decommissioning - absent' do
    let(:params) { {:absent => true, :monitor => true , :firewall => true, :port => '42', 
      :forward_server => '127.0.0.1', :deployment_server => '127.0.0.1', :monitor_path => '/dir/file' } }

    it 'should remove Package[splunk]' do should contain_package('splunk').with_ensure('absent') end 
    it 'should stop Service[splunk]' do should contain_service('splunk').with_ensure('stopped') end
    it 'should not enable at boot Service[splunk]' do should contain_service('splunk').with_enable('false') end
    it 'should not have directory dependencies left' do
      should contain_file('splunk_add_forward_server').with_ensure('absent')
      should contain_file('splunk_deployment_server').with_ensure('absent')
      should contain_file('splunk_add_monitor').with_ensure('absent')
      should contain_file('splunk_change_admin_password').with_ensure('absent')
    end
    it 'should not monitor the process' do
      content = catalogue.resource('monitor::process', 'splunk_process').send(:parameters)[:enable]
      content.should == false
    end
    it 'should remove a firewall rule' do
      content = catalogue.resource('firewall', 'splunk_tcp_42').send(:parameters)[:enable]
      content.should == false
    end
  end

  describe 'Test decommissioning - disable' do
    let(:params) { {:disable => true, :monitor => true , :firewall => true, :port => '42'} }

    it { should contain_package('splunk').with_ensure('latest') }
    it 'should stop Service[splunk]' do should contain_service('splunk').with_ensure('stopped') end
    it 'should not enable at boot Service[splunk]' do should contain_service('splunk').with_enable('false') end
    it 'should not monitor the process' do
      content = catalogue.resource('monitor::process', 'splunk_process').send(:parameters)[:enable]
      content.should == false
    end
    it 'should remove a firewall rule' do
      content = catalogue.resource('firewall', 'splunk_tcp_42').send(:parameters)[:enable]
      content.should == false
    end
  end

  describe 'Test decommissioning - disableboot' do
    let(:params) { {:disableboot => true, :monitor => true , :firewall => true, :port => '42'} }
  
    it { should contain_package('splunk').with_ensure('latest') }
    it { should_not contain_service('splunk').with_ensure('latest') }
    it { should_not contain_service('splunk').with_ensure('absent') }
    it 'should not enable at boot Service[splunk]' do should contain_service('splunk').with_enable('false') end
    it 'should not monitor the process locally' do
      content = catalogue.resource('monitor::process', 'splunk_process').send(:parameters)[:enable]
      content.should == false
    end
    it 'should keep a firewall rule' do
      content = catalogue.resource('firewall', 'splunk_tcp_42').send(:parameters)[:enable]
      content.should == true
    end
  end 

  describe 'Test customizations - template_inputs' do
    let(:params) { {:template_inputs => "splunk/spec.erb" , :options => { 'opt_a' => 'value_a' } } }

    it 'should generate a valid template' do
      content = catalogue.resource('file', 'splunk_inputs.conf').send(:parameters)[:content]
      content.should match "fqdn: rspec.example42.com"
    end
    it 'should generate a template that uses custom options' do
      content = catalogue.resource('file', 'splunk_inputs.conf').send(:parameters)[:content]
      content.should match "value_a"
    end

  end

  describe 'Test customizations - source_dir' do
    let(:params) { {:source_dir => "puppet://modules/splunk/dir/spec" , :source_dir_purge => true } }

    it 'should request a valid source dir' do
      content = catalogue.resource('file', 'splunk.dir').send(:parameters)[:source]
      content.should == "puppet://modules/splunk/dir/spec"
    end
    it 'should purge source dir if source_dir_purge is true' do
      content = catalogue.resource('file', 'splunk.dir').send(:parameters)[:purge]
      content.should == true
    end
  end

  describe 'Test customizations - custom class' do
    let(:params) { {:my_class => "splunk::spec", :template_outputs => "splunk/spec.erb" } }
    it 'should automatically include a custom class' do
      content = catalogue.resource('file', 'splunk_outputs.conf').send(:parameters)[:owner]
      content.should match "spec"
    end
  end

  describe 'Test Puppi Integration' do
    let(:params) { {:puppi => true, :puppi_helper => "myhelper"} }

    it 'should generate a puppi::ze define' do
      content = catalogue.resource('puppi::ze', 'splunk').send(:parameters)[:helper]
      content.should == "myhelper"
    end
  end

  describe 'Test Monitoring Tools Integration' do
    let(:params) { {:monitor => true, :monitor_tool => "puppi" } }

    it 'should generate monitor defines' do
      content = catalogue.resource('monitor::process', 'splunk_process').send(:parameters)[:tool]
      content.should == "puppi"
    end
  end

  describe 'Test Firewall Tools Integration' do
    let(:params) { {:firewall => true, :firewall_tool => "iptables" , :protocol => "tcp" , :port => "42" } }

    it 'should generate correct firewall define' do
      content = catalogue.resource('firewall', 'splunk_tcp_42').send(:parameters)[:tool]
      content.should == "iptables"
    end
  end

  describe 'Test OldGen Module Set Integration' do
    let(:params) { {:monitor => "yes" , :monitor_tool => "puppi" , :firewall => "yes" , :firewall_tool => "iptables" , :puppi => "yes" , :port => "42" } }

    it 'should generate monitor resources' do
      content = catalogue.resource('monitor::process', 'splunk_process').send(:parameters)[:tool]
      content.should == "puppi"
    end
    it 'should generate firewall resources' do
      content = catalogue.resource('firewall', 'splunk_tcp_42').send(:parameters)[:tool]
      content.should == "iptables"
    end
    it 'should generate puppi resources ' do 
      content = catalogue.resource('puppi::ze', 'splunk').send(:parameters)[:ensure]
      content.should == "present"
    end
  end

end
