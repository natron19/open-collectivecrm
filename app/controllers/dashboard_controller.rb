class DashboardController < ApplicationController
  def show
    @leads_by_stage = Lead::STAGES.index_with { |stage|
      current_user.leads.where(stage: stage).order(created_at: :desc)
    }
    @seller_profile = current_user.seller_profile
  end
end
