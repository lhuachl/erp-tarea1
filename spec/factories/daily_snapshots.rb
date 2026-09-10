FactoryBot.define do
  factory :daily_snapshot do
    sprint
    fecha { Date.current }
    puntos_restantes { 21 }
    horas_restantes { 40 }
  end
end
