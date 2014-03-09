class InstallationsController < ActionController::Base
  # lots more stuff...

  def schedule
    if installation.pending_credit_check?
      installation_pending_credit_check
      return
    end

    audit_trail_for(current_user) do
      begin
        if installation.schedule!(desired_date, :installation_type => installation_type, :city => installation.city)
          if installation.scheduled_date
            schedule_installation_successful
          end
        else
          schedule_installation_failed
        end
      rescue Exception => e
        schedule_installation_failed_with_an_error(e)
      end

      schedule_installation_complete
    end
  end

  private

  def installation_pending_credit_check
    if request.xhr?
      render :json => {:errors => ["Cannot schedule installation while credit check is pending"]}, :status => 400
    else
      flash[:error] = "Cannot schedule installation while credit check is pending"
      redirect_to installations_path(:city_id => installation.city_id, :view => "calendar")
    end
  end

  def schedule_installation_successful
    if request.xhr?
      date = installation.scheduled_date.in_time_zone(installation.city.timezone).to_date
      render :json => {:errors => nil, :html => schedule_response(installation, date)}
    else
      if installation.customer_provided_equipment?
        flash[:success] = %Q{Installation scheduled}
      else
        flash[:success] = %Q{Installation scheduled! Don't forget to order the equipment also.}
      end
    end
  end

  def schedule_installation_failed
    if request.xhr?
      render :json => {:errors => [%Q{Could not update installation. #{installation.errors.full_messages.join(' ')}}] }
    else
      flash[:error] = %Q{Could not schedule installation, check the phase of the moon}
    end
  end

  def schedule_installation_failed_with_an_error(e)
    if request.xhr?
      if e.is_a?(ActiveRecord::RecordInvalid)
        render :json => {:errors => [e.message] }
      elsif e.is_a?(ArgumentError)
        render :json => {:errors => ["Could not schedule installation. Start by making sure the desired date is on a business day."]}
      else
        raise
      end
    else
      flash[:error] = e.message
    end
  end

  def schedule_installation_complete
    unless request.xhr?
      redirect_to(installation.customer_provided_equipment? ? customer_provided_installations_path : installations_path(:city_id => installation.city_id, :view => "calendar"))
    end
  end

  def desired_date
    params[:desired_date]
  end

  def installation_type
    params[:installation_type]
  end

  def installation
    @installation
  end
  # lots more stuff...
end
