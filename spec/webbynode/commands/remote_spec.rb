# Load Spec Helper
require File.join(File.expand_path(File.dirname(__FILE__)), '../..', 'spec_helper')

describe Webbynode::Commands::Remote do
  
  def load_all_mocks(rem=remote)
    rem.should_receive(:remote_executor).any_number_of_times.and_return(re)
    rem.should_receive(:git).any_number_of_times.and_return(git)
    rem.should_receive(:io).any_number_of_times.and_return(io)
    rem.should_receive(:pushand).any_number_of_times.and_return(pushand)
    rem.should_receive(:server).any_number_of_times.and_return(server)
  end
  
  let(:re)      { double("RemoteExecutor").as_null_object }
  let(:git)     { double("Git").as_null_object }
  let(:pushand) { double("Pushand").as_null_object }
  let(:server)  { double("Server").as_null_object }
  let(:ssh)     { double("SSh").as_null_object }
  let(:io)      { double("Io").as_null_object }
  let(:remote)  { Webbynode::Commands::Remote.new('ls -la') }
 
  before do
    load_all_mocks
  end
  
  it "should notify the user" do
    io.should_receive(:log).with("Performing the requested remote command..", true)
    remote.run
  end
 
  context "when successful" do    
    it "should receive at least one option when passing in the remote command" do
      remote = Webbynode::Commands::Remote.new('ls')
      remote.params.first.value.should eql(['ls'])
    end
    
    it "multiple options will be joined together if multiple options are provided" do
      remote = Webbynode::Commands::Remote.new('ls -la')
      remote.params.first.value.should eql(['ls -la'])
    end
    
    it "should establish a connection with the server" do
      remote = Webbynode::Commands::Remote.new('ls -la')
      remote.stub(:validate_initialization)
      load_all_mocks(remote)
      pushand.should_receive(:parse_remote_app_name).and_return('test.webbynode.com')
      re.should_receive(:exec).with("cd test.webbynode.com; ls -la", true)
      remote.run
    end
    
    it "should consider all parameters a single command" do
      remote = Webbynode::Commands::Remote.new('these', 'are', 'the', 'params')
      pushand.should_receive(:parse_remote_app_name).and_return('webbynode')
      load_all_mocks(remote)
      remote.stub(:validate_initialization)
      remote.stub(:validate_remote_application_availability)
                  
      re.should_receive(:exec).with("cd webbynode; these are the params", true)
      remote.run
    end
    
    it "should parse the pushand file for the application folder name on the remote server" do
      remote.stub(:validate_initialization)
      pushand.should_receive(:parse_remote_app_name).and_return("dummy_app")
      remote.run
    end

  end
  
  context "when unsuccesful" do    
    it "should raise an error if no options are provided" do
      Webbynode::Commands::Remote.new.run
      stdout.should =~ /Missing 'command' parameter/
    end
  end
end