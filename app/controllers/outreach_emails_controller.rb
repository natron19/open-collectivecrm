class OutreachEmailsController < ApplicationController
  before_action :set_outreach_email

  def show
  end

  def destroy
    lead = @outreach_email.lead
    @outreach_email.destroy
    redirect_to lead_path(lead), notice: "Outreach email deleted."
  end

  private

  def set_outreach_email
    @outreach_email = OutreachEmail
      .joins(:lead)
      .where(leads: { user_id: current_user.id })
      .find(params[:id])
  end
end
