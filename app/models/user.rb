# == Schema Information
#
# Table name: users
#
#  id               :bigint           not null, primary key
#  email            :string           not null
#  password_digest  :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  confirmed_at      :datetime
#
# Indexes
#
#  index_users_on_email  (email) UNIQUE
#
class User < ApplicationRecord
  has_secure_password

  has_many :user_assets, dependent: :destroy
  has_many :user_liabilities, dependent: :destroy
  has_many :budget_items, dependent: :destroy
  has_many :ai_messages, dependent: :destroy

  validates :email, presence: true, uniqueness: true
  validates_format_of :email, with: URI::MailTo::EMAIL_REGEXP
  validates :password, length: { minimum: 6 }

  def confirm!
    update_columns(confirmed_at: Time.current)
  end

  def confirmed?
    confirmed_at.present?
  end

  def unconfirmed?
    !confirmed?
  end

  def generate_confirmation_token
    signed_id expires_in: 15.minutes
  end

  def send_confirmation_email!
    confirmation_token = generate_confirmation_token
    UserMailer.confirmation(self, confirmation_token).deliver_now
  end

  # Total value of all assets at each month from the first purchase to today,
  # using each asset's depreciation curve. Suitable for chartkick.
  def asset_value_timeline
    assets = user_assets.where.not(purchase_date: nil)
                        .includes(:asset_valuations, :asset_contributions).to_a
    return {} if assets.empty?

    monthly_timeline(assets.map(&:purchase_date).min) do |date|
      assets.sum { |asset| asset.value_at(date) }
    end
  end

  # Budget surplus per month in cents (income minus bills minus everyday),
  # or nil when there is no budget income recorded.
  def monthly_budget_surplus_cents
    income = budget_items.in_section("income").sum(&:yearly_cents)
    return nil if income.zero?

    expenses = budget_items.where(section: %w[bills everyday]).sum(&:yearly_cents)
    ((income - expenses) / 12.0).round
  end

  # Cumulative liabilities at each month, dated by when each was added.
  def liability_timeline
    liabilities = user_liabilities.to_a
    return {} if liabilities.empty?

    monthly_timeline(liabilities.map { |l| l.created_at.to_date }.min) do |date|
      liabilities.sum { |l| l.created_at.to_date <= date ? l.amount_cents : 0 }
    end
  end

  private

  def monthly_timeline(start_date)
    timeline = {}
    date = start_date.beginning_of_month
    while date <= Date.today
      timeline[date.strftime("%b %Y")] = (yield(date) / 100.0).round(2)
      date = date.next_month
    end
    timeline[Date.today.strftime("%b %Y")] = (yield(Date.today) / 100.0).round(2)
    timeline
  end
end
