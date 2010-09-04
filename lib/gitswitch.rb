require "optparse"
require "yaml"

class GitSwitch
  VERSION_FILE = File.join File.dirname(__FILE__), "..", "VERSION.yml"
  GITSWITCH_CONFIG_FILE = File.join ENV["HOME"], ".gitswitch"
  GIT_BIN = '/usr/bin/env git'
  

  def self.run args = ARGV
    gitswitch = GitSwitch.new
    gitswitch.parse_args args
  end


  def initialize
    @users = {}
    if File.exists? GITSWITCH_CONFIG_FILE
      @users = YAML::load_file GITSWITCH_CONFIG_FILE
      raise "Error loading .gitswitch file" if @users.nil?
    else
      print "Gitswitch users file ~/.gitswitch not found.  Would you like to create one? (y/n): "
      if gets.chomp =~ /^y/i
        create_gitswitch_file
      else
        puts "Ok, that's fine.  Exiting." and exit
      end
    end

  end


  # Read and parse the supplied command line arguments.
  def parse_args args = ARGV
    args = ["-h"] if args.empty?

    parser = OptionParser.new do |o|
      o.banner = "Usage: gitswitch [options]"

      o.on "-l", "--list", "Show all git users you have configured" do
        list_users and exit
      end

      o.on "-i", "--info", "Show the current git user info." do
        print_info and exit
      end

      o.on "-s", "--switch [TAG]", String, "Switch git user to the specified tag" do |tag|
        tag ||= 'default'
        switch_user tag
        print_info
        exit
      end

      o.on "-r", "--repo [TAG]", String, "Switch git user to the specified tag for the current directory's git repository" do |tag|
        tag ||= 'default'
        switch_repo_user tag
        exit
      end

      o.on "-h", "--help", "Show this help message." do
        print_info
        puts parser and exit
      end

      o.on "-o", "--overwrite", "Overwrite/create a .gitswitch file using your current git user info as default" do
        create_gitswitch_file
        print_info and exit
      end

      o.on "-a", "--add", "Add a new gitswitch entry" do
        add_gitswitch_entry and exit
      end

      o.on("-v", "--version", "Show the current version.") do
        print_version and exit
      end      
    end
    

    begin
      parser.parse! args
    rescue OptionParser::InvalidOption => error
      puts error.message.capitalize
    rescue OptionParser::MissingArgument => error
      puts error.message.capitalize
    end
  end
  


  # Create a .gitswitch file with the current user defaults
  def create_gitswitch_file
    current_git_user = get_current_git_user
    if current_git_user[:name].empty? && current_git_user[:email].empty?
      puts "ERROR: You must set up a default git user.name and user.email first."
    else
      puts "Adding your current git user info to the \"default\" tag..."
      set_gitswitch_entry('default', current_git_user[:email], current_git_user[:name])
      save_gitswitch_file
    end
  end


  def save_gitswitch_file
    if fh = File.open(GITSWITCH_CONFIG_FILE, 'w')
      fh.write(@users.to_yaml)
      fh.close
    else
      puts "ERROR: Could not open/write the gitswitch config file: #{GITSWITCH_CONFIG_FILE}"
    end
  end


  # Set git user parameters for a tag
  # ==== Parameters
  # * +tag+ - Required. The tag you want to add to your .gitswitch file
  # * +email+ - Required
  # * +name+ - Required
  def set_gitswitch_entry(tag, email, name)
    @users[tag] = {:name => name, :email => email}
    save_gitswitch_file
  end

  
  # Switch git user in your global .gitconfig file
  # ==== Parameters
  # * +tag+ - The tag associated with your desired git info in .gitswitch.  Defaults to "default".
  def switch_global_user tag = "default"
    puts "Switching git user to \"#{tag}\" tag..."
    if !@users[tag].empty? && !@users[tag][:email].to_s.empty?
      %x(#{GIT_BIN} config --replace-all --global user.name '#{@users[tag][:name]}') if !@users[tag][:name].to_s.empty?
      %x(#{GIT_BIN} config --replace-all --global user.email '#{@users[tag][:email]}')
    else
      puts "ERROR: Could not find info for tag #{tag} in your .gitswitch file"
    end
  end


  # Set the git user information for current repository
  # ==== Parameters
  # * +tag+ - The tag associated with your desired git info in .gitswitch. Defaults to "default".
  def switch_repo_user tag = "default"
    puts "Switching git user to \"#{tag}\" tag..."
    if !@users[tag].empty? && !@users[tag][:email].to_s.empty?
      %x(#{GIT_BIN} config --replace-all user.name '#{@users[tag][:name]}') if !@users[tag][:name].to_s.empty?
      %x(#{GIT_BIN} config --replace-all user.email '#{@users[tag][:email]}')
    else
      puts "ERROR: Could not find info for tag #{tag} in your .gitswitch file"
    end
  end
  
  
  # Add a user entry to your .gitswitch file
  def add_gitswitch_entry
    print "What tag would you like to set to this git user? "
    tag = gets.chomp
      
    print "E-mail address: "
    email = gets.chomp

    print "Name: (ENTER to use \"" + get_current_git_user()[:name] + "\") "
    name = gets.chomp
    if name.empty?
      name = get_current_git_user()[:name]
    end
    set_gitswitch_entry(tag, email, name)
  end
  
  
  def list_users
    puts "\nCurrent git user options --"
    @users.each do |key, user|
      puts "#{key}:"
      puts "  Name:   #{user[:name]}" if !user[:name].to_s.empty?
      puts "  E-mail: #{user[:email]}\n"
    end
  end

  
  # Print active account information.
  def print_info
    current_git_user = get_current_git_user
    puts "Current git user information:\n"
    puts "Name:   #{current_git_user[:name]}" 
    puts "E-mail: #{current_git_user[:email]}"
    puts
  end

  
  # Print version information.
  def print_version
    if fh = File.open('VERSION','r')
      puts "GitSwitch " + fh.gets
      fh.close
    else
      puts "Version information not found"
    end
  end

  
  private

  # Show the current git user info
  def get_current_git_user
    user = {
      :name => %x(#{GIT_BIN} config --get user.name).to_s.chomp,
      :email => %x(#{GIT_BIN} config --get user.email).to_s.chomp
    } 
  end
  
end
