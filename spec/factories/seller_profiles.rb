FactoryBot.define do
  factory :seller_profile do
    user
    product_name        { "TestProduct" }
    product_description { "A product that helps teams work better." }
  end
end
