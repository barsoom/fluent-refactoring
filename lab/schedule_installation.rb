class ScheduleInstallation
  pattr_initialize :installation, :installation_type, :desired_date, :responder

  def run
    if installation.pending_credit_check?
      credit_check_is_pending
    else
      schedule_installation
    end
  end

  private

  delegate :credit_check_is_pending,
    :installation_scheduled,
    :installation_failed,
    :could_not_schedule_installation,
    :installation_scheduling_complete,
    to: :responder

  def schedule_installation
    begin
      if installation.schedule!(desired_date, :installation_type => installation_type, :city => installation.city)
        if installation.scheduled_date
          installation_scheduled
        end
      else
        could_not_schedule_installation
      end
    rescue Exception => e
      installation_failed(e)
    end

    installation_scheduling_complete
  end
end
