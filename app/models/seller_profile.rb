class SellerProfile < ApplicationRecord
  belongs_to :user

  validates :product_name,        presence: true
  validates :product_description, presence: true, length: { maximum: 500 }
  validates :user_id,             uniqueness: true
end
