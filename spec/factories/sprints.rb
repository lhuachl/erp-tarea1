FactoryBot.define do
  factory :sprint do
    nombre { "Sprint 1" }
    fecha_inicio { Date.current }
    fecha_fin { Date.current + 10 }
  end
end
