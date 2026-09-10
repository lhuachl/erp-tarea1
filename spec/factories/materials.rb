FactoryBot.define do
  factory :material do
    sequence(:nombre) { |n| "Material #{n}" }
    unidad { "kg" }
  end

  factory :stock_movement do
    material
    tipo { "entrada" }
    cantidad { 1 }
  end
end
