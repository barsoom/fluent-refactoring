class ScheduleInstallationXhrResponder
  pattr_initialize :controller

  delegate :request, :render, :schedule_response, :installation, to: :controller

  def credit_check_is_pending
    render :json => {:errors => ["Cannot schedule installation while credit check is pending"]}, :status => 400
  end

  def installation_scheduled
    date = installation.scheduled_date.in_time_zone(installation.city.timezone).to_date
    render :json => {:errors => nil, :html => schedule_response(installation, date)}
  end

  def installation_failed(exception)
    case exception
    when ActiveRecord::RecordInvalid
      error_message = exception.message
    when ArgumentError
      error_message = "Could not schedule installation. Start by making sure the desired date is on a business day."
    else
      # TODO: this isn't covered by tests
      raise exception
    end

    render :json => {:errors => [error_message] }
  end

  def could_not_schedule_installation
    render :json => {:errors => [%Q{Could not update installation. #{installation.errors.full_messages.join(' ')}}] }
  end

  def installation_scheduling_complete
  end
end
