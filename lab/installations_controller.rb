require "attr_extras"
require_relative "installation_scheduler"

class InstallationsController < ActionController::Base
  # lots more stuff...

  def schedule
    InstallationScheduler.new(self, @installation, current_user).run
  end


  # lots more stuff...
end
