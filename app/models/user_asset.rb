# == Schema Information
#
# Table name: user_assets
#
#  id                      :bigint           not null, primary key
#  item_name               :string           not null
#  purchase_price_cents    :integer          not null
#  purchase_price_currency :string           default("AUD"), not null
#  purchase_date           :date             not null
#  user_id                 :integer          not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
# Indexes
#
#  index_user_assets_on_user_id  (user_id)
#

class UserAsset < ApplicationRecord
  belongs_to :user
  has_many :asset_contributions, dependent: :destroy
  has_many :asset_valuations, dependent: :destroy

  DEPRECIATION_METHODS = {
    'none' => 'No Depreciation',
    'straight_line' => 'Straight Line',
    'declining_balance' => 'Declining Balance',
    'double_declining' => 'Double Declining Balance'
  }.freeze
  
  validates :item_name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :purchase_price_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :purchase_price_currency, presence: true, inclusion: { in: %w[AUD USD EUR GBP JPY] }
  validates :purchase_date, presence: true
  validates :depreciation_method, inclusion: { in: DEPRECIATION_METHODS.keys }
  validates :salvage_value_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  
  validate :purchase_date_not_in_future
  validate :depreciation_fields_presence
  validate :salvage_value_less_than_purchase_price
  
  # A market asset (shares, cash, super) is valued by marks-to-market rather
  # than a depreciation curve.
  def market_asset?
    depreciation_method == 'none'
  end

  # Everything paid in up to a date: the original purchase plus contributions.
  def cost_basis_cents(date = Date.today)
    purchase_price_cents +
      asset_contributions.to_a.select { |c| c.occurred_on <= date }.sum(&:amount_cents)
  end

  # Value on a date. Market assets: the latest valuation on/before that date,
  # plus any contributions made after it (new money holds face value until the
  # next mark); with no valuations yet, cost basis. Depreciating assets: the
  # depreciation curve.
  def value_at(date)
    return 0 if purchase_date.nil? || date < purchase_date

    unless market_asset?
      return current_value_at_year((date - purchase_date).to_f / 365.25)
    end

    mark = asset_valuations.to_a.select { |v| v.valued_on <= date }.max_by(&:valued_on)
    if mark
      later_contributions = asset_contributions.to_a
        .select { |c| c.occurred_on > mark.valued_on && c.occurred_on <= date }
        .sum(&:amount_cents)
      mark.value_cents + later_contributions
    else
      cost_basis_cents(date)
    end
  end

  def gain_cents
    current_value_cents - cost_basis_cents
  end

  # Money-weighted annualised return across purchase, contributions and the
  # current value. nil when it can't be meaningfully computed.
  def money_weighted_return
    return nil unless market_asset? && purchase_date.present?

    cashflows = [[purchase_date, -purchase_price_cents]]
    asset_contributions.each { |c| cashflows << [c.occurred_on, -c.amount_cents] }
    cashflows << [Date.today, current_value_cents]

    AssetPerformance::Xirr.new(cashflows).call
  end

  # Monthly series of money-in vs value from purchase to today, for charting.
  def performance_timeline
    return {} unless market_asset? && purchase_date.present?

    dates = []
    date = purchase_date
    while date <= Date.today
      dates << date
      date = date.next_month.beginning_of_month
    end
    dates << Date.today unless dates.last == Date.today

    {
      basis: dates.index_with { |d| (cost_basis_cents(d) / 100.0).round(2) },
      value: dates.index_with { |d| (value_at(d) / 100.0).round(2) }
    }
  end

  # Calculate current depreciated value
  def current_value_cents
    return value_at(Date.today) if depreciation_method == 'none'

    years_owned = calculate_years_owned
    return purchase_price_cents if years_owned <= 0
    
    case depreciation_method
    when 'straight_line'
      straight_line_value(years_owned)
    when 'declining_balance'
      declining_balance_value(years_owned)
    when 'double_declining'
      double_declining_value(years_owned)
    else
      purchase_price_cents
    end
  end
  
  def current_value
    current_value_cents / 100.0
  end
  
  def annual_depreciation_cents
    return 0 if depreciation_method == 'none' || useful_life_years.nil? || useful_life_years == 0
    
    case depreciation_method
    when 'straight_line'
      (purchase_price_cents - (salvage_value_cents || 0)) / useful_life_years
    else
      # For declining balance methods, depreciation varies by year
      current_year_depreciation
    end
  end
  
  def depreciation_percentage
    return 0 if depreciation_method == 'none' || purchase_price_cents == 0
    
    depreciated_amount = purchase_price_cents - current_value_cents
    (depreciated_amount.to_f / purchase_price_cents * 100).round(2)
  end
  
  # Generate data for depreciation chart
  def depreciation_chart_data
    return {} if depreciation_method == 'none' || purchase_date.blank?
    
    chart_data = {}
    start_date = purchase_date
    years_owned = calculate_years_owned
    
    # Calculate max years to show (current ownership + 2 years future, or useful life + 2)
    max_years = if useful_life_years.present?
      [years_owned + 2, useful_life_years + 2].max
    else
      years_owned + 2
    end
    
    # Generate monthly data points for smoother chart
    (0..(max_years * 12)).each do |month|
      year_fraction = month / 12.0
      date = start_date + (year_fraction * 365.25).days
      
      # Stop if we're too far in the future
      break if year_fraction > max_years
      
      value_cents = current_value_at_year(year_fraction)
      value_dollars = value_cents / 100.0
      
      chart_data[date.strftime("%b %Y")] = value_dollars
    end
    
    chart_data
  end
  
  # Generate simplified yearly data for smaller charts
  def yearly_depreciation_data
    return {} if depreciation_method == 'none' || purchase_date.blank?
    
    chart_data = {}
    years_owned = calculate_years_owned
    
    # Show from purchase year to current year + 1
    start_year = purchase_date.year
    end_year = Date.today.year + 1
    
    (start_year..end_year).each do |year|
      year_fraction = year - purchase_date.year
      next if year_fraction < 0
      
      value_cents = current_value_at_year(year_fraction)
      value_dollars = value_cents / 100.0
      
      chart_data[year.to_s] = value_dollars
    end
    
    chart_data
  end

  def current_value_at_year(year)
    return purchase_price_cents if year <= 0
    
    case depreciation_method
    when 'straight_line'
      straight_line_value(year)
    when 'declining_balance'
      declining_balance_value(year)
    when 'double_declining'
      double_declining_value(year)
    else
      purchase_price_cents
    end
  end

  def calculate_years_owned
    return 0 unless purchase_date.present?
    ((Date.today - purchase_date).to_f / 365.25).to_f
  end

  private
  
  def purchase_date_not_in_future
    if purchase_date.present? && purchase_date > Date.today
      errors.add(:purchase_date, "can't be in the future")
    end
  end
  
  def depreciation_fields_presence
    if depreciation_method.present? && depreciation_method != 'none'
      if depreciation_method == 'straight_line' && (useful_life_years.blank? || useful_life_years.to_i <= 0)
        errors.add(:useful_life_years, "must be a positive number for straight line depreciation (got: #{useful_life_years.inspect})")
      elsif depreciation_method == 'double_declining' && (useful_life_years.blank? || useful_life_years.to_i <= 0)
        errors.add(:useful_life_years, "must be a positive number for double declining depreciation (got: #{useful_life_years.inspect})")
      elsif ['declining_balance', 'double_declining'].include?(depreciation_method) && (depreciation_rate.blank? || depreciation_rate.to_f <= 0)
        errors.add(:depreciation_rate, "must be a positive number for declining balance depreciation (got: #{depreciation_rate.inspect})")
      end
    end
  end
  
  def salvage_value_less_than_purchase_price
    if salvage_value_cents.present? && purchase_price_cents.present? && salvage_value_cents >= purchase_price_cents
      errors.add(:salvage_value_cents, "must be less than purchase price")
    end
  end
  
  def straight_line_value(years_owned)
    return purchase_price_cents if useful_life_years.nil? || useful_life_years == 0
    
    salvage = salvage_value_cents || 0
    annual_depreciation = (purchase_price_cents - salvage) / useful_life_years.to_f
    
    depreciation_years = [years_owned, useful_life_years].min
    depreciated_value = purchase_price_cents - (annual_depreciation * depreciation_years)
    
    [depreciated_value, salvage].max.round
  end
  
  def declining_balance_value(years_owned)
    return purchase_price_cents unless depreciation_rate.present?
    
    rate = depreciation_rate / 100.0
    salvage = salvage_value_cents || 0
    current_value = purchase_price_cents
    
    years_owned.floor.times do
      current_value = current_value * (1 - rate)
    end
    
    # Account for partial year
    if years_owned % 1 != 0
      partial_year = years_owned % 1
      current_value = current_value * (1 - (rate * partial_year))
    end
    
    [current_value, salvage].max.round
  end
  
  def double_declining_value(years_owned)
    return purchase_price_cents unless useful_life_years.present? && useful_life_years > 0
    
    rate = (2.0 / useful_life_years)
    salvage = salvage_value_cents || 0
    current_value = purchase_price_cents
    
    years_owned.floor.times do
      annual_depreciation = current_value * rate
      current_value = current_value - annual_depreciation
      current_value = [current_value, salvage].max
    end
    
    # Account for partial year
    if years_owned % 1 != 0 && current_value > salvage
      partial_year = years_owned % 1
      annual_depreciation = current_value * rate * partial_year
      current_value = current_value - annual_depreciation
    end
    
    [current_value, salvage].max.round
  end
  
  def current_year_depreciation
    return 0 if depreciation_method == 'none'
    
    years_owned = calculate_years_owned
    current_year_start_value = current_value_at_year(years_owned.floor)
    current_year_end_value = current_value_at_year(years_owned.floor + 1)
    
    current_year_start_value - current_year_end_value
  end
end