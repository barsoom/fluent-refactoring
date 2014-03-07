require "attr_extras"

class ScheduleInstallation
  def initialize(opts)
    @responder = opts.fetch(:responder)
    @installation = opts.fetch(:installation)
    @city = opts.fetch(:city)
    @installation_type = opts.fetch(:installation_type)
    @desired_date = opts.fetch(:desired_date)
  end

  attr_private :responder, :installation, :city, :installation_type, :desired_date

  def run
    if installation.pending_credit_check?
      responder.pending_credit_check(installation)
      return
    end

    if request.xhr?
      responder.schedule_installation(
        installation: installation,
        installation_type: installation_type,
        city: city,
        desired_date: desired_date,
      )
    else  # if not XHR
      begin
        responder.schedule_installation(
          installation: installation,
          installation_type: installation_type,
          city: city,
          desired_date: desired_date,
        )
      rescue => e
        flash[:error] = e.message
      end
      redirect_to(installation.customer_provided_equipment? ? customer_provided_installations_path : installations_path(:city_id => installation.city_id, :view => "calendar"))
    end
  end

  private

  delegate :request, :current_user,
    :redirect_to, :flash, :render,
    :audit_trail_for, :schedule_response,
    :installations_path, :customer_provided_installations_path,
    to: :responder
end

class InstallationsController < ActionController::Base
  class ScheduleAjaxResponder
    pattr_initialize :controller

    def pending_credit_check(installation)
      render :json => {:errors => ["Cannot schedule installation while credit check is pending"]}, :status => 400
    end

    def schedule_installation(opts)
      installation = opts.fetch(:installation)
      installation_type = opts.fetch(:installation_type)
      city = opts.fetch(:city)
      desired_date = opts.fetch(:desired_date)

      audit_trail_for(current_user) do
        if installation.schedule!(desired_date, :installation_type => installation_type, :city => city)
          if installation.scheduled_date
            installation_scheduled(installation)
          end
        else
          installation_failed(installation)
        end
      end

    rescue ActiveRecord::RecordInvalid => e
      render :json => {:errors => [e.message] }
    rescue ArgumentError => e
      render :json => {:errors => ["Could not schedule installation. Start by making sure the desired date is on a business day."]}
    end

    private

    def installation_failed(installation)
      render :json => {:errors => [%Q{Could not update installation. #{installation.errors.full_messages.join(' ')}}] }
    end

    def installation_scheduled(installation)
      date = installation.scheduled_date.in_time_zone(installation.city.timezone).to_date
      render :json => {:errors => nil, :html => schedule_response(installation, date)}
    end

    delegate :request, :current_user,
      :redirect_to, :flash, :render,
      :audit_trail_for, :schedule_response,
      :installations_path, :customer_provided_installations_path,
      to: :controller
  end

  class ScheduleHtmlResponder
    pattr_initialize :controller

    def pending_credit_check(installation)
      flash[:error] = "Cannot schedule installation while credit check is pending"
      redirect_to installations_path(:city_id => installation.city_id, :view => "calendar")
    end

    def schedule_installation(opts)
      installation = opts.fetch(:installation)
      installation_type = opts.fetch(:installation_type)
      city = opts.fetch(:city)
      desired_date = opts.fetch(:desired_date)

      audit_trail_for(current_user) do
        if installation.schedule!(desired_date, :installation_type => installation_type, :city => city)
          if installation.scheduled_date
            installation_scheduled(installation)
          end
        else
          installation_failed(installation)
        end
      end
    end

    private

    def installation_failed(installation)
      flash[:error] = %Q{Could not schedule installation, check the phase of the moon}
    end

    def installation_scheduled(installation)
      if installation.customer_provided_equipment?
        flash[:success] = %Q{Installation scheduled}
      else
        flash[:success] = %Q{Installation scheduled! Don't forget to order the equipment also.}
      end
    end

    delegate :request, :current_user,
      :redirect_to, :flash, :render,
      :audit_trail_for, :schedule_response,
      :installations_path, :customer_provided_installations_path,
      to: :controller
  end

  def schedule
    responder = request.xhr? ? ScheduleAjaxResponder.new(self) : ScheduleHtmlResponder.new(self)

    ScheduleInstallation.new(
      responder: responder,
      installation: @installation,
      city: @city,
      installation_type: params[:installation_type],
      desired_date: params[:desired_date],
    ).run
  end

  # lots more stuff...
end
