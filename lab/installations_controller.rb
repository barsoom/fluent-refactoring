class InstallationsController < ActionController::Base
  # lots more stuff...
  
  class XhrRender
    def initialize(installation_controller)
      @controller = installation_controller
    end
    
    def installation_failed_for_unknown_reason
      render :json => {:errors => [%Q{Could not update installation. #{installation.errors.full_messages.join(' ')}}] }      
    end

    def installation_error(e)
      if e.is_a?(ActiveRecord::RecordInvalid)
        render :json => {:errors => [e.message] }
      elsif e.is_a?(ArgumentError)
        render :json => {:errors => ["Could not schedule installation. Start by making sure the desired date is on a business day."]}
      else
        raise
      end
    end

    def installation_scheduled  
      date = installation.scheduled_date.in_time_zone(installation.city.timezone).to_date
      render :json => {:errors => nil, :html => schedule_response(installation, date)}
    end

    def installation_complete
    end

    def pending_credit_check
      render :json => {:errors => ["Cannot schedule installation while credit check is pending"]}, :status => 400
    end

    delegate :render,
      :installation,
      :schedule_response,
      to: :controller
    
      attr_reader :controller
  end

  class WebRender
    def initialize(installation_controller)
      @controller = installation_controller
    end

    def installation_error(e)
      flash[:error] = e.message
    end

    def installation_failed_for_unknown_reason
      flash[:error] = %Q{Could not schedule installation, check the phase of the moon}
    end
    
    def installation_scheduled
      if installation.customer_provided_equipment?
        flash[:success] = %Q{Installation scheduled}
      else
        flash[:success] = %Q{Installation scheduled! Don't forget to order the equipment also.}
      end      
    end

    def installation_complete
      redirect_to(installation.customer_provided_equipment? ? customer_provided_installations_path : installations_path(:city_id => installation.city_id, :view => "calendar"))
    end

    def pending_credit_check
      flash[:error] = "Cannot schedule installation while credit check is pending"
      redirect_to installations_path(:city_id => installation.city_id, :view => "calendar")
    end

    delegate :installations_path, 
      :flash, 
      :customer_provided_installations_path, 
      :schedule_response,
      :installation,
      :redirect_to,
      to: :controller

    attr_reader :controller
  end

  
  def schedule    
    audit_trail_for(current_user) do
      if request.xhr?
        schedule_installation(XhrRender.new(self))
      else
        schedule_installation(WebRender.new(self))
      end
    end
  end

  attr_reader :installation
  
  def schedule_installation(renderer)
    if installation.pending_credit_check?
      renderer.pending_credit_check
      return
    end

    desired_date = params[:desired_date]
    
    begin
      if installation.schedule!(desired_date, :installation_type => params[:installation_type], :city => @city)
        if installation.scheduled_date
          renderer.installation_scheduled              
        end
      else
        renderer.installation_failed_for_unknown_reason
      end
    rescue Exception => e
      renderer.installation_error(e)
    end
    renderer.installation_complete
  end    
  
  # lots more stuff...
end
