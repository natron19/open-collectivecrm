FactoryBot.define do
  factory :lead do
    user
    first_name   { "Jordan" }
    last_name    { "Ellis" }
    company      { "Acme Corp" }
    company_size { "startup" }
    role         { "Head of Growth" }
    stage        { "prospect" }

    trait :smb do
      company_size { "smb" }
    end

    trait :enterprise do
      company_size { "enterprise" }
      company      { "BigCo Inc" }
    end

    trait :contacted do
      stage { "contacted" }
    end

    trait :qualified do
      stage { "qualified" }
    end

    trait :proposal do
      stage { "proposal" }
    end

    trait :closed do
      stage { "closed" }
    end
  end
end
