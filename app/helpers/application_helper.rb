module ApplicationHelper
  def flash_bootstrap_class(type)
    { "notice" => "success", "alert" => "danger", "info" => "info", "warning" => "warning" }
      .fetch(type.to_s, "secondary")
  end

  def angle_badge_class(angle)
    { "value" => "bg-warning text-dark", "problem" => "bg-primary", "referral" => "bg-success" }
      .fetch(angle.to_s, "bg-secondary")
  end
end
