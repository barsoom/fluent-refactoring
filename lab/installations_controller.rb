require "attr_extras"
require_relative "schedule_installation"
require_relative "schedule_installation_xhr_responder"
require_relative "schedule_installation_web_responder"

# Odd things:
# - schedule_response just exists somewhere on the stubbed controller
# - xhr does not have a successful response
# - xhr responds in multiple ways, seems like the API design could be improved
# - dumping exception messages out to the user...
#
# If I really worked on this app I would take a deeper look and probably
# refactor the models a bit too. Not only code problems here, usability,
# unknown states, ...

class InstallationsController < ActionController::Base
  # lots more stuff...

  attr_private :installation

  def schedule
    with_audit_trail do
      ScheduleInstallation.new(installation, installation_type, desired_date, schedule_responder).run
    end
  end

  private

  def schedule_responder
    if request.xhr?
      ScheduleInstallationXhrResponder.new(self)
    else
      ScheduleInstallationWebResponder.new(self)
    end
  end

  def installation_type
    params[:installation_type]
  end

  def desired_date
    params[:desired_date]
  end

  def with_audit_trail(&block)
    audit_trail_for(current_user, &block)
  end

# lots more stuff...
end
