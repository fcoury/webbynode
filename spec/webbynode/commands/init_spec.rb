# Load Spec Helper
require File.join(File.expand_path(File.dirname(__FILE__)), '../..', 'spec_helper')

describe Webbynode::Commands::Init do
  let(:git_handler) { double("dummy_git_handler").as_null_object }
  let(:io_handler)  { double("dummy_io_handler").as_null_object }
  
  def create_init(ip="4.3.2.1", host=nil, extra=[])
    @command = Webbynode::Commands::Init.new(ip, host, *extra)
    @command.should_receive(:git).any_number_of_times.and_return(git_handler) 
    @command.should_receive(:io).any_number_of_times.and_return(io_handler)
  end
  
  before(:each) do
    FakeWeb.clean_registry
    create_init
  end
  
  context "selecting an engine" do
    it "should create the .webbynode/engine file" do
      command = Webbynode::Commands::Init.new("10.0.1.1", "--engine=php")
      command.option(:engine).should == 'php'
      command.should_receive(:io).any_number_of_times.and_return(io_handler)

      io_handler.should_receive(:create_file).with(".webbynode/engine", "php")
      command.run
    end
  end
  
  context "when creating a DNS entry with --adddns option" do
    def create_init(ip="4.3.2.1", host=nil, extra=[])
      @command = Webbynode::Commands::Init.new(ip, host, *extra)
      @command.should_receive(:git).any_number_of_times.and_return(git_handler) 
    end

    it "should setup DNS using Webbynode API" do
      create_init("10.0.1.1", "new.rubyista.info", "--adddns")

      api = Webbynode::ApiClient.new
      api.should_receive(:create_record).with("new.rubyista.info", "10.0.1.1")
      git_handler.should_receive(:parse_remote_ip).and_return("10.0.1.1")

      @command.should_receive(:api).any_number_of_times.and_return(api)
      @command.run
    end

    it "should setup empty and www records for a tld" do
      create_init("10.0.1.1", "rubyista.info", "--adddns")

      io = double("Io").as_null_object
      io.should_receive(:create_file).with(".webbynode/config", "DNS_ALIAS='www.rubyista.info'")

      api = Webbynode::ApiClient.new
      api.should_receive(:create_record).with("rubyista.info", "10.0.1.1")
      api.should_receive(:create_record).with("www.rubyista.info", "10.0.1.1")
      git_handler.should_receive(:parse_remote_ip).any_number_of_times.and_return("10.0.1.1")

      @command.should_receive(:api).any_number_of_times.and_return(api)
      @command.should_receive(:io).any_number_of_times.and_return(io)
      @command.run
    end

    it "should setup empty and www records for a non-.com tld" do
      create_init("10.0.1.1", "rubyista.com.br", "--adddns")

      api = Webbynode::ApiClient.new
      api.should_receive(:create_record).with("rubyista.com.br", "10.0.1.1")
      api.should_receive(:create_record).with("www.rubyista.com.br", "10.0.1.1")
      git_handler.should_receive(:parse_remote_ip).any_number_of_times.and_return("10.0.1.1")

      @command.should_receive(:api).any_number_of_times.and_return(api)
      @command.run
    end

    it "should indicate the record already exists" do
      create_init("10.0.1.1", "new.rubyista.info", "--adddns")

      api = Webbynode::ApiClient.new
      api.should_receive(:create_record).with("new.rubyista.info", "10.0.1.1").and_raise(Webbynode::ApiClient::ApiError.new("Data has already been taken"))
      git_handler.should_receive(:parse_remote_ip).and_return("10.0.1.1")

      @command.should_receive(:api).any_number_of_times.and_return(api)
      @command.run
      
      stdout.should =~ /The DNS entry for 'new.rubyista.info' already existed, ignoring./
    end

    it "should show an user friendly error" do
      create_init("10.0.1.1", "new.rubyista.info", "--adddns")

      api = Webbynode::ApiClient.new
      git_handler.should_receive(:parse_remote_ip).and_return("10.0.1.1")
      api.should_receive(:create_record).with("new.rubyista.info", "10.0.1.1").and_raise(Webbynode::ApiClient::ApiError.new("No DNS entry for id 99999"))

      @command.should_receive(:api).any_number_of_times.and_return(api)
      @command.run
      
      stdout.should =~ /Couldn't create your DNS entry: No DNS entry for id 99999/
    end
  end
  
  it "should ask for user's login email if no credentials" do
    FakeWeb.register_uri(:post, "#{Webbynode::ApiClient.base_uri}/webbies", 
      :email => "fcoury@me.com", :response => read_fixture("api/webbies"))

    io_handler.should_receive(:file_exists?).with(Webbynode::ApiClient::CREDENTIALS_FILE).and_return(false)
    io_handler.should_receive(:app_name).any_number_of_times.and_return("my_app")
    io_handler.should_receive(:create_file).with(Webbynode::ApiClient::CREDENTIALS_FILE, "email = abc123\ntoken = 234def\n")

    create_init("my_webby_name")
    @command.api.should_receive(:io).any_number_of_times.and_return(io_handler)
    @command.api.should_receive(:ask).with("API token:   ").and_return("234def")
    @command.api.should_receive(:ask).with("Login email: ").and_return("abc123")
    @command.run
    
    stdout.should =~ /Couldn't find Webby 'my_webby_name' on your account. Your Webbies are/
    stdout.should =~ /'webby3067'/
    stdout.should =~ /' and '/
    stdout.should =~ /'sandbox'/
  end
  
  it "should report the error if user provides wrong credentials" do
    FakeWeb.register_uri(:post, "#{Webbynode::ApiClient.base_uri}/webbies", 
      :email => "fcoury@me.com", :response => read_fixture("api/webbies_unauthorized"))

    io_handler.should_receive(:app_name).any_number_of_times.and_return("my_app")
    io_handler.should_receive(:create_file).never

    create_init("my_webby_name")

    @command.api.should_receive(:ip_for).and_raise(Webbynode::ApiClient::Unauthorized)
    @command.run

    stdout.should =~ /Your credentials didn't match any Webbynode account./
  end
  
  it "should report Webby doesn't exist" do
    api = double("ApiClient")
    api.should_receive(:ip_for).with("my_webby_name").and_return(nil)
    api.should_receive(:webbies).and_return({
      "one_webby"=>{:name => 'one_webby', :other => 'other'}, 
      "another_webby"=>{:name => 'another_webby', :other => 'other'}
    })
    
    io_handler.should_receive(:app_name).any_number_of_times.and_return("my_app")

    create_init("my_webby_name")
    @command.should_receive(:api).any_number_of_times.and_return(api)
    @command.run
    
    stdout.should =~ /Couldn't find Webby 'my_webby_name' on your account. Your Webbies are/
    stdout.should =~ /'one_webby'/
    stdout.should =~ /' and '/
    stdout.should =~ /'another_webby'/
  end
  
  it "should report user doesn't have Webbies" do
    api = double("ApiClient")
    api.should_receive(:ip_for).with("my_webby_name").and_return(nil)
    api.should_receive(:webbies).and_return({})
    
    io_handler.should_receive(:app_name).any_number_of_times.and_return("my_app")

    create_init("my_webby_name")
    @command.should_receive(:api).any_number_of_times.and_return(api)
    @command.run
    
    stdout.should =~ /You don't have any active Webbies on your account./
  end
  
  it "should try to get Webby's IP if no IP given" do
    api = double("ApiClient")
    api.should_receive(:ip_for).with("my_webby_name").and_return("1.2.3.4")
    
    io_handler.should_receive(:app_name).any_number_of_times.and_return("my_app")
    git_handler.should_receive(:present?).and_return(false)
    git_handler.should_receive(:add_remote).with("webbynode", "1.2.3.4", "my_app")

    create_init("my_webby_name")
    @command.should_receive(:api).and_return(api)
    @command.run
  end
  
  context "determining host" do
    it "should assume host is app's name when not given" do
      io_handler.should_receive(:file_exists?).with(".pushand").and_return(false)
      io_handler.should_receive(:app_name).any_number_of_times.and_return("application_name")
      io_handler.should_receive(:create_file).with(".pushand", "#! /bin/bash\nphd $0 application_name\n", true)
    
      @command.run
    end
  
    it "should assume host is app's name when not given" do
      create_init("1.2.3.4", "my.com.br")
      
      io_handler.should_receive(:file_exists?).with(".pushand").and_return(false)
      io_handler.should_receive(:app_name).any_number_of_times.and_return("application_name")
      io_handler.should_receive(:create_file).with(".pushand", "#! /bin/bash\nphd $0 application_name my.com.br\n", true)
    
      @command.run
    end
  end
  
  context "when .gitignore is not present" do
    it "should create the standard .gitignore" do
      io_handler.should_receive(:file_exists?).with(".gitignore").and_return(false)
      git_handler.should_receive(:add_git_ignore)
      
      @command.run
    end
  end
  
  context "when .webbynode is not present" do
    it "should create the .webbynode system folder and stub files" do
      io_handler.should_receive(:directory?).with(".webbynode").and_return(false)
      io_handler.should_receive(:exec).with("mkdir -p .webbynode/tasks")
      io_handler.should_receive(:create_file).with(".webbynode/tasks/after_push", "")
      io_handler.should_receive(:create_file).with(".webbynode/tasks/before_push", "")
      io_handler.should_receive(:create_file).with(".webbynode/aliases", "")
      
      @command.run
    end
  end
  
  context "when .pushand is not present" do
    it "should be created and made an executable" do
      io_handler.should_receive(:file_exists?).with(".pushand").and_return(false)
      io_handler.should_receive(:app_name).any_number_of_times.and_return("mah_app")
      io_handler.should_receive(:create_file).with(".pushand", "#! /bin/bash\nphd $0 mah_app\n", true)
      
      @command.run
    end
  end
  
  context "when .pushand is present" do
    it "should not be created" do
      io_handler.should_receive(:file_exists?).with(".pushand").and_return(true)
      io_handler.should_receive(:create_file).never
      
      @command.run
    end
  end
  
  context "when git repo doesn't exist yet" do
    it "should create a new git repo" do
      git_handler.should_receive(:present?).and_return(false)
      git_handler.should_receive(:init)

      @command.run
    end
    
    it "should add a new remote" do
      io_handler.should_receive(:app_name).any_number_of_times.and_return("my_app")
      git_handler.should_receive(:present?).and_return(false)
      git_handler.should_receive(:add_remote).with("webbynode", "4.3.2.1", "my_app")

      @command.run
    end
    
    it "should add everything" do
      git_handler.should_receive(:present?).and_return(false)
      git_handler.should_receive(:add).with(".")

      @command.run
    end
  
    it "should create the initial commit" do
      git_handler.should_receive(:present?).and_return(false)
      git_handler.should_receive(:commit).with("Initial commit")
      
      @command.run
    end
    
    it "should log a message to the user when it's finished" do
      io_handler.should_receive(:app_name).any_number_of_times.and_return("my_app")
      io_handler.should_receive(:log).with("Application my_app ready for Rapid Deployment", :finish)
      
      @command.run
    end
  end

  context "when git repo is initialized" do
    it "should not create a commit" do
      git_handler.should_receive(:present?).and_return(true)
      git_handler.should_receive(:commit).never

      @command.run
    end

    it "should try to add a remote" do
      git_handler.should_receive(:present?).and_return(true)
      git_handler.should_receive(:add_remote)

      @command.run
    end
    
    it "should tell the user it's already initialized" do
      git_handler.should_receive(:present?).and_return(true)
      git_handler.should_receive(:add_remote).and_raise(Webbynode::GitRemoteAlreadyExistsError)
      
      io_handler.should_receive(:log).with("Application already initialized.", true)
      @command.run
    end
  end
end
