require "attr_extras"

class InstallationsController < ActionController::Base
  # lots more stuff...

  def schedule
    InstallationScheduler.new(self, @installation, current_user).run
  end

  class InstallationScheduler
    pattr_initialize :client, :installation, :current_user

    def run
      desired_date = client.params[:desired_date]
      if client.request.xhr?
        begin
          if installation.pending_credit_check?
            client.render :json => {:errors => ["Cannot schedule installation while credit check is pending"]}, :status => 400
            return
          end
          client.audit_trail_for(current_user) do
            if installation.schedule!(desired_date, :installation_type => client.params[:installation_type], :city => installation.city)
              if installation.scheduled_date
                date = installation.scheduled_date.in_time_zone(installation.city.timezone).to_date
                client.render :json => {:errors => nil, :html => client.schedule_response(installation, date)}
              end
            else
              client.render :json => {:errors => [%Q{Could not update installation. #{installation.errors.full_messages.join(' ')}}] }
            end
          end
        rescue ActiveRecord::RecordInvalid => e
          client.render :json => {:errors => [e.message] }
        rescue ArgumentError => e
          client.render :json => {:errors => ["Could not schedule installation. Start by making sure the desired date is on a business day."]}
        end
      else
        if installation.pending_credit_check?
          client.flash[:error] = "Cannot schedule installation while credit check is pending"
          client.redirect_to client.installations_path(:city_id => installation.city_id, :view => "calendar") and return
        end
        begin
          client.audit_trail_for(current_user) do
            if installation.schedule!(desired_date, :installation_type => client.params[:installation_type], :city => @city)
              if installation.scheduled_date
                if installation.customer_provided_equipment?
                  client.flash[:success] = %Q{Installation scheduled}
                else
                  client.flash[:success] = %Q{Installation scheduled! Don't forget to order the equipment also.}
                end
              end
            else
              client.flash[:error] = %Q{Could not schedule installation, check the phase of the moon}
            end
          end
        rescue => e
          client.flash[:error] = e.message
        end
        client.redirect_to(installation.customer_provided_equipment? ? client.customer_provided_installations_path : client.installations_path(:city_id => installation.city_id, :view => "calendar"))
      end
    end
  end

  # lots more stuff...
end
