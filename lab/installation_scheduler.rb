class InstallationScheduler
  pattr_initialize :client, :installation, :current_user

  def run_with_audit
    client.audit_trail_for(current_user) do
      run
    end
  end

  def run
    desired_date = client.params[:desired_date]

    if installation.pending_credit_check?
      render_pending_credit_check
      return
    end

    if xhr?
      begin
        if installation.schedule!(desired_date, :installation_type => client.params[:installation_type], :city => installation.city)
          if installation.scheduled_date
            render_success
          end
        else
          render_error(%Q{Could not update installation. #{installation.errors.full_messages.join(' ')}})
        end
      rescue ActiveRecord::RecordInvalid => e
        render_error e.message
      rescue ArgumentError => e
        render_error "Could not schedule installation. Start by making sure the desired date is on a business day."
      end
    else
      begin
        if installation.schedule!(desired_date, :installation_type => client.params[:installation_type], :city => installation.city)
          if installation.scheduled_date
            render_success
          end
        else
          render_error %Q{Could not schedule installation, check the phase of the moon}
        end
      rescue => e
        render_error(e.message)
      end
      client.redirect_to(installation.customer_provided_equipment? ? client.customer_provided_installations_path : client.installations_path(:city_id => installation.city_id, :view => "calendar"))
    end
  end

  private

  def render_success
    if xhr?
      date = installation.scheduled_date.in_time_zone(installation.city.timezone).to_date
      client.render :json => {:errors => nil, :html => client.schedule_response(installation, date)}
    else
      if installation.customer_provided_equipment?
        client.flash[:success] = %Q{Installation scheduled}
      else
        client.flash[:success] = %Q{Installation scheduled! Don't forget to order the equipment also.}
      end
    end
  end

  def render_error(error)
    if xhr?
      client.render :json => {:errors => [error]}
    else
      client.flash[:error] = error
    end
  end

  def xhr?
    client.request.xhr?
  end

  def render_pending_credit_check
    if xhr?
      client.render :json => {:errors => ["Cannot schedule installation while credit check is pending"]}, :status => 400
    else
      client.flash[:error] = "Cannot schedule installation while credit check is pending"
      client.redirect_to client.installations_path(:city_id => installation.city_id, :view => "calendar")
    end
  end
end
