module Webbynode::Commands
  class Version < Webbynode::Command
    summary "Displays current version of Webbynode Gem"
    def execute
      io.log("Rapid Deployment Gem v#{Webbynode::VERSION}", true)
    end
  end
end