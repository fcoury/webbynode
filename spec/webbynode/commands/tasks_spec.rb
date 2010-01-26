# Load Spec Helper
require File.join(File.expand_path(File.dirname(__FILE__)), '../..', 'spec_helper')

describe Webbynode::Commands::Tasks do
  
  it "should have constants defining the paths to the task files" do
    tasks_class = Webbynode::Commands::Tasks
    tasks_class::TasksPath.should             eql(".webbynode/tasks")
    tasks_class::BeforeCreateTasksFile.should eql(".webbynode/tasks/before_create")
    tasks_class::AfterCreateTasksFile.should  eql(".webbynode/tasks/after_create")
    tasks_class::BeforePushTasksFile.should   eql(".webbynode/tasks/before_push")
    tasks_class::AfterPushTasksFile.should    eql(".webbynode/tasks/after_push")
  end
  
  let(:io)    { double('io').as_null_object }
  let(:task)  { Webbynode::Commands::Tasks.new(['add', 'after_push', 'rake', 'db:migrate', 'RAILS_ENV=production']) }
  
  before(:each) do
    task.should_receive(:io).any_number_of_times.and_return(io)
  end
  
  it "should parse the params provided by the user" do
    task.should_receive(:parse_parameters)
    task.stub!(:send)
    task.execute
  end
  
  it "should have correctly parsed and stored the user input" do
    task.execute
    task.action.should  eql("add")
    task.type.should    eql("after_push")
    task.command.should eql("rake db:migrate RAILS_ENV=production")
  end
  
  it "should invoke the validate_parameters method" do
    task.should_receive(:validate_parameters)
    task.execute
  end
  
  it "should set the current path for the specified task interaction type" do
    task.should_receive(:set_selected_file)
    task.execute
  end
  
  describe "selectable paths" do
    def selectable_helper(type)
      @task = @tasks_class.new(["add", type])
      @task.stub!(:validate_parameters)
      @task.stub!(:send)
      @task.should_receive(:io).any_number_of_times.and_return(io)
      @task.execute
    end
    
    before(:each) do
      @tasks_class = Webbynode::Commands::Tasks
    end
    
    it "should be the before_create path" do
      selectable_helper('before_create')
      @task.selected_file.should eql(@tasks_class::BeforeCreateTasksFile)
    end
    
    it "should be the before_create path" do
      selectable_helper('after_create')
      @task.selected_file.should eql(@tasks_class::AfterCreateTasksFile)
    end
    
    it "should be the before_create path" do
      selectable_helper('before_push')
      @task.selected_file.should eql(@tasks_class::BeforePushTasksFile)
    end
    
    it "should be the before_create path" do
      selectable_helper('after_push')
      @task.selected_file.should eql(@tasks_class::AfterPushTasksFile)
    end
  end
  
  context "should initialize the [add] or [remove] action, depending on user input" do
    it "should have a [add] and [remove] method availble" do
      task.private_methods.should include('add')
      task.private_methods.should include('remove')
    end
    
    it "should initialize the [add] method" do
      task.should_receive(:send).with('add')
      task.execute
    end
    
    it "should initialize the [remove] method" do
      task = Webbynode::Commands::Tasks.new(['remove', 'after_push', 'rake', 'db:migrate', 'RAILS_ENV=production'])
      task.should_receive(:send).with('remove')
      task.stub!(:read_tasks)
      task.execute
    end
  end
  
  describe "adding tasks to a file" do
    before(:each) do
      task.should_receive(:io).any_number_of_times.and_return(io)
    end
    
    context "when successful" do
      it "should read the specified file" do
        task.should_receive(:read_tasks).with('.webbynode/tasks/after_push')
        task.stub!(:send)
        task.execute
      end
      
      it "should append the new task to the array" do
        task.should_receive(:append_task).with('rake db:migrate RAILS_ENV=production')
        task.execute
      end
      
      it "should have appended the new task to the array" do
        task.execute
        task.selected_tasks.should include('rake db:migrate RAILS_ENV=production')
      end
      
      it "should write a new file with the updated task list" do
        task.should_receive(:write_tasks)
        task.execute
      end
      
      it "should display the updated list of tasks" do
        task.should_receive(:puts).with("These are the current tasks for \"After push\":")
        task.should_receive(:puts).with("[0] rake db:migrate RAILS_ENV=production")
        task.execute
      end
    end
  end
  
  describe "removing tasks from a file" do
    let(:rtask) { Webbynode::Commands::Tasks.new(['remove', 'after_push', 1]) }
    
    before(:each) do
      rtask.should_receive(:io).any_number_of_times.and_return(io)
    end
    
    context "when successful" do
      it "should initialize the [remove] method" do
        rtask.should_receive(:send).with('remove')
        rtask.execute
      end
      
      it "should remove the task from the list of available tasks" do
        rtask.should_receive(:delete_task).with(1)
        rtask.execute
      end
      
      it "should write the new tasks" do
        rtask.should_receive(:write_tasks)
        rtask.execute
      end
      
      it "should display the updated list of tasks" do
        3.times {|num| rtask.selected_tasks << "task#{num}" }
        rtask.stub(:read_tasks)
        rtask.should_receive(:puts).with("These are the current tasks for \"After push\":")
        rtask.should_receive(:puts).with("[0] task0")
        rtask.should_not_receive(:puts).with("[1] task1")
        rtask.should_receive(:puts).with("[1] task2")
        rtask.execute
        rtask.selected_tasks.should include("task0")
        rtask.selected_tasks.should_not include("task1")
        rtask.selected_tasks.should include("task2")
      end
    end
  end
end