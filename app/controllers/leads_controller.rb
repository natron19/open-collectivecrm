class LeadsController < ApplicationController
  before_action :set_lead, only: [:show, :edit, :update, :destroy, :generate_outreach]

  rate_limit to: 5, within: 1.minute, only: [:generate_outreach],
             with: -> {
               render turbo_stream: turbo_stream.update("outreach_progress",
                 "<div class='alert alert-warning'>Please wait before generating again.</div>")
             }

  def index
    redirect_to dashboard_path
  end

  def new
    @lead = Lead.new(stage: params[:stage].presence || "prospect")
  end

  def create
    @lead = current_user.leads.build(lead_params)
    if @lead.save
      redirect_to lead_path(@lead), notice: "Lead created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @outreach_emails = @lead.outreach_emails.order(created_at: :desc)
    @seller_profile  = current_user.seller_profile
  end

  def edit
  end

  def update
    if @lead.update(lead_params)
      respond_to do |format|
        format.turbo_stream do
          flash.now[:notice] = "Stage updated."
          render turbo_stream: [
            turbo_stream.update("lead_stage_badge", partial: "leads/stage_badge", locals: { lead: @lead }),
            turbo_stream.update("flash", partial: "shared/flash")
          ]
        end
        format.html { redirect_to lead_path(@lead), notice: "Lead updated." }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @lead.destroy
    redirect_to dashboard_path, notice: "Lead deleted."
  end

  def generate_outreach
    @seller_profile = current_user.seller_profile

    unless @seller_profile
      render turbo_stream: turbo_stream.update("outreach_progress",
        "<div class='alert alert-warning'>Please set up your <a href='#{edit_seller_profile_path}'>seller profile</a> before generating outreach.</div>")
      return
    end

    angle         = params[:angle].presence || "value"
    template_name = @lead.company_size == "enterprise" ?
      "collectivecrm_outreach_enterprise_v1" :
      "collectivecrm_outreach_startup_v1"

    result  = GeminiService.generate_with_tools(
      template:  template_name,
      variables: outreach_variables(@lead, @seller_profile, angle),
      user:      current_user
    )
    raw     = result[:raw].strip.gsub(/\A```(?:json)?\s*/i, "").gsub(/\s*```\z/, "")
    parsed  = JSON.parse(raw)
    @outreach_email = OutreachEmail.create!(
      lead:             @lead,
      angle:            angle,
      subject:          parsed["subject"],
      body:             parsed["body"],
      research_summary: parsed["research_summary"],
      sources:          Array(parsed["sources"]).join("\n"),
      agent_trace:      result[:trace].to_json,
      gemini_raw:       raw
    )

    render turbo_stream: [
      turbo_stream.update("outreach_progress", ""),
      turbo_stream.prepend("outreach_results",
        partial: "outreach_emails/outreach_email",
        locals:  { outreach_email: @outreach_email })
    ]

  rescue JSON::ParserError
    render turbo_stream: turbo_stream.update("outreach_progress",
      render_to_string(partial: "shared/ai_error", locals: { error_type: :error }))
  rescue GeminiService::BudgetExceededError
    render turbo_stream: turbo_stream.update("outreach_progress",
      render_to_string(partial: "shared/ai_error", locals: { error_type: :budget_exceeded }))
  rescue GeminiService::GatekeeperError
    render turbo_stream: turbo_stream.update("outreach_progress",
      render_to_string(partial: "shared/ai_error", locals: { error_type: :gatekeeper_blocked }))
  rescue GeminiService::TimeoutError
    render turbo_stream: turbo_stream.update("outreach_progress",
      render_to_string(partial: "shared/ai_error", locals: { error_type: :timeout }))
  rescue GeminiService::GeminiError
    render turbo_stream: turbo_stream.update("outreach_progress",
      render_to_string(partial: "shared/ai_error", locals: { error_type: :error }))
  end

  private

  def set_lead
    @lead = current_user.leads.find(params[:id])
  end

  def outreach_variables(lead, profile, angle)
    {
      first_name:          lead.first_name,
      last_name:           lead.last_name,
      role:                lead.role.to_s,
      company:             lead.company,
      company_size:        lead.company_size,
      website:             lead.website.to_s,
      notes:               lead.notes.to_s,
      product_name:        profile.product_name,
      product_description: profile.product_description,
      angle:               angle
    }
  end

  def lead_params
    params.require(:lead).permit(
      :first_name, :last_name, :company, :company_size,
      :role, :email, :website, :stage, :notes
    )
  end
end
