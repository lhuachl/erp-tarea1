FactoryBot.define do
  factory :client do
    sequence(:nombre) { |n| "Cliente #{n}" }
    telefono { nil }
  end
end
