class OutreachEmail < ApplicationRecord
  belongs_to :lead

  ANGLES = %w[value problem referral].freeze

  validates :angle, presence: true, inclusion: { in: ANGLES }
end
