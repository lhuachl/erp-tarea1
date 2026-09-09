class User < ApplicationRecord
  ROLES = %w[admin operador].freeze

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum :role, ROLES.index_by(&:itself), default: :operador

  validates :role, inclusion: { in: ROLES }

  def admin?
    role == "admin"
  end

  def operador?
    role == "operador"
  end
end
