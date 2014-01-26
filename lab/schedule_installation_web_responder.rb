class ScheduleInstallationWebResponder
  pattr_initialize :controller

  delegate :flash, :render, :redirect_to, :installation, :installations_path, :customer_provided_installations_path, to: :controller

  def installation_scheduling_complete
    url = installation.customer_provided_equipment? ?
      customer_provided_installations_path :
      installations_path(:city_id => installation.city_id, :view => "calendar")

    redirect_to(url)
  end

  def credit_check_is_pending
    flash[:error] = "Cannot schedule installation while credit check is pending"
    redirect_to installations_path(:city_id => installation.city_id, :view => "calendar") and return
  end

  def installation_failed(exception)
    flash[:error] = exception.message
  end

  def installation_scheduled
    if installation.customer_provided_equipment?
      flash[:success] = %Q{Installation scheduled}
    else
      flash[:success] = %Q{Installation scheduled! Don't forget to order the equipment also.}
    end
  end

  def could_not_schedule_installation
    flash[:error] = %Q{Could not schedule installation, check the phase of the moon}
  end
end
