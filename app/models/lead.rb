class Lead < ApplicationRecord
  belongs_to :user
  has_many :outreach_emails, dependent: :destroy

  STAGES       = %w[prospect contacted qualified proposal closed].freeze
  COMPANY_SIZES = %w[startup smb enterprise].freeze

  validates :first_name, :last_name, :company, :company_size, :stage, presence: true
  validates :stage,        inclusion: { in: STAGES }
  validates :company_size, inclusion: { in: COMPANY_SIZES }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  scope :grouped_by_stage, -> {
    STAGES.index_with { |stage| where(stage: stage).order(created_at: :desc) }
  }
end
